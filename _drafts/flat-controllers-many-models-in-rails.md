---
layout: default
title: Flat Controllers, Many Models in Rails
---

# Flat Controllers, Many Models in Rails

A change that looks local turns out to touch five things. A callback fires. An after-commit hook runs. A scope with a side effect triggers a query you didn't write. The problem isn't Rails — it's that logic is hiding. The codebase has become hard to narrate.

## The judgment test

Here's how you know something is hiding: open any procedure — a controller action, a job, a worker — and try to narrate it to a non-technical stakeholder in near real-time. Can you see all the inputs? Can you account for every mutation? If you can't, something is hiding. Callbacks, side-effecting models, logic tucked into scopes — all of them fail this test.

The rest of this post is organized around passing it.

## Three concepts, not three files

MVC is usually taught as three files. More useful: three concepts.

- **Procedures** — explicit sequences of steps triggered by an external event.
- **Transformations** — objects with defined input/output contracts and no external side effects.
- **I/O** — anything that touches external state.

This framing tells you what each layer is *for* and what it should never do.

## Procedures

A procedure is an explicit sequence of steps triggered by an external event. Controllers are procedures — but so are Jobs, Workers, Mailers, and Rake tasks. The same discipline applies to all of them: read top-to-bottom and see every input and every mutation.

```ruby
def create
  @form = OrderForm.new(Order.new(user: current_user), order_params)
  if @form.valid?
    @form.order.save!
    redirect_to @form.order
  else
    render :new
  end
end
```

A job follows the same shape:

```ruby
class SendWeeklyDigestJob < ApplicationJob
  def perform(user_id)
    user   = User.find(user_id)
    digest = DigestQuery.new(user).call
    DigestMailer.weekly(user, digest).deliver_now if digest.any?
  end
end
```

Both read as a flat sequence. No hidden steps.

## Transformations, I/O, and where AR models fit

**Transformations** are objects with no external side effects. **Form objects** are the canonical example: input is a model plus user-submitted params; output is a Boolean (valid?) plus the populated model. No persistence — that belongs in the procedure. **Permission objects** (policies) are another: input is a user and a resource; output is a Boolean. No queries triggered implicitly, no state changed — the procedure decides what to do with the result.

```ruby
class OrderForm
  include ActiveModel::Model
  attr_reader :order

  def initialize(order, params = {})
    @order = order.tap { |o| o.assign_attributes(params) }
    super(params)
  end

  validates :quantity, numericality: { greater_than: 0 }
end
```

**I/O objects** are anything that touches external state. **Query objects** are I/O — they read from the database and belong in the procedure's explicit sequence, not inside a model method or scope. I/O deserves particular attention because I/O produces *artifacts*: records other flows read, emails users receive, jobs workers process. These artifacts carry forward into downstream user experiences and business outcomes. When I/O is hidden in a callback or a side-effecting scope, you lose the ability to trace which procedures produce which artifacts and what downstream work they trigger.

**ActiveRecord models** span transformations (validations, domain methods) and exactly *one* I/O boundary: persistence. That's fine. The problem is when callbacks add more I/O — emails, API calls, enqueued jobs — making the model's boundary invisible to the procedure reading it and hiding the artifacts those operations produce.

## Two scenarios where this earns its keep

**Multiple models in one action.** A checkout action that saves an order and a payment. A Form object holds references to both; the controller still reads as a flat sequence:

```ruby
class CheckoutForm
  include ActiveModel::Model
  attr_reader :order, :payment

  def initialize(order, payment, params = {})
    @order   = order.tap   { |o| o.assign_attributes(params[:order]   || {}) }
    @payment = payment.tap { |p| p.assign_attributes(params[:payment] || {}) }
    super(params)
  end

  validate :order_valid, :payment_valid
  def order_valid;   errors.add(:order,   "invalid") unless order.valid?;   end
  def payment_valid; errors.add(:payment, "invalid") unless payment.valid?; end
end

def checkout
  @form = CheckoutForm.new(@order, Payment.new, checkout_params)
  if @form.valid?
    @form.order.save!
    @form.payment.save!
    redirect_to confirmation_path
  else
    render :checkout
  end
end
```

**Preventing N+1s.** Separating I/O from transformation makes N+1s structurally impossible. The procedure sequences: fetch all records once → transform each (no DB calls) → write results. When query logic and transformation logic are mixed, the query sneaks into the loop.

```ruby
class SendWeeklyDigestsJob < ApplicationJob
  def perform
    users   = DigestableUsersQuery.new.call          # I/O: one query
    digests = users.map { |u| DigestBuilder.new(u) } # Transformation: no DB calls
    digests.each { |d| DigestMailer.weekly(d).deliver_now } # I/O: send
  end
end
```

When procedures are explicit and transformations have clean I/O contracts, changes become tractable. You know what each object takes and produces. You can narrate the code.
