---
layout: default
title: Flat Controllers, Many Models in Rails
---

# Flat Controllers, Many Models in Rails

The goal of a product engineer isn't to maintain a codebase. It's to evolve it: to introduce something that didn't exist before, to move an idea from concept to production before the window closes. Radical change is the work. The constraint on that work is almost always comprehension: you can't responsibly reshape what you don't understand.

That understanding is often missing. Codebases grow in ways that obscure their own behavior. A change that looks local turns out to touch five things. A callback fires somewhere downstream. A scope with a side effect triggers a query you didn't write. The more the system has grown, the more the gap between "what this code appears to do" and "what this code actually does" widens.

The testing experience makes the gap concrete. You want to validate your change, but you don't know what state the world needs to be in at the start. What records do you create? Which associations matter? You add factories until the test passes, then wonder if the setup reflects anything real. As the data model grows, the gap between "setup that makes tests pass" and "setup that reflects real-world behavior" widens. You end up with tests you can't fully trust, not because the assertions are wrong, but because you aren't sure the setup is right.

## The judgment test

Here's how you know something is hiding: open any procedure (a controller action, a job, a script) and try to narrate it to a colleague. Can you see all the inputs? Can you account for every mutation? If you can't, something is hiding. Callbacks, side-effecting models, logic tucked into scopes: all of them fail this test.

Passing it requires a deliberate choice about which layer owns what.

## Three concepts, not three files

MVC is usually taught as three files. More useful: three concepts.

- **Procedures**: explicit sequences of steps triggered by an external event.
- **Transformations**: objects with defined input/output contracts and no external side effects.
- **I/O**: anything that touches external state.

This framing tells you what each layer is *for* and what it should never do.

## One control plane

Web requests, jobs, and tasks are the application's **control plane**: the only layer whose job is orchestration. Naming this matters because it identifies what must stay singular. Service objects fail long-term not because they're wrong in principle, but because they create a second control plane. Engineers can't tell whether orchestration belongs in the controller or the service. Services start calling jobs. Jobs call other services. You end up with two layers that both orchestrate, neither with full visibility.

That framing makes the failure mode clear: a service object that fetches records, validates inputs, saves a model, and enqueues a job isn't a transformation; it's a procedure in disguise. Moving it out of the controller doesn't remove the orchestration; it just hides it one level deeper and splits the reader's attention between two places.

## Procedures

A procedure is an explicit sequence of steps triggered by an external event. Controllers are procedures, but so are Jobs, Workers, Mailers, and Rake tasks. The same discipline applies to all of them: read top-to-bottom and see every input and every mutation.

```ruby
class OrdersController < ApplicationController
  def create
    cart  = current_user.current_cart
    @form = OrderForm.new(cart, order_params)
    if @form.valid?
      ActiveRecord::Base.transaction do
        @form.order.save!
        cart.complete!
      end
      NotifyPurchaserJob.perform_later(@form.order)
      NotifyMerchantJob.perform_later(@form.order)
      redirect_to @form.order
    else
      render :new
    end
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

Both read as flat sequences with no hidden steps.

This isn't a defense of long procedures. Every line in a procedure should earn its place as a business step. Noise (intermediate variables that just rename concepts, complex rules embedded inline) should be extracted. The question is what kind of extraction. A procedure that grows because it has ten genuine business steps is fine. A procedure cluttered with implementation detail that could be named and isolated is not. Extract the detail; keep the orchestration.

This is what separates a long, thin procedure from a fat one. A fat controller grows because logic accumulates: validations, decisions, business rules all collapse into one place. A long, thin controller grows because the domain is genuinely complex: ten real business steps, each visible, each named. The discipline that keeps it thin is removing what isn't a business step. A single-use variable that just renames a concept is noise. A conditional that could be a named policy object is noise. Length from business necessity is fine. Length from accumulated detail is the problem.

A concrete form of that noise: single-use variables. In practice: avoid creating a variable in a procedure unless it's used at least twice. A variable used once is usually just an alias, a rename that adds a line without adding meaning. A variable used twice has a reason to exist: you're holding a result to coordinate two subsequent steps, which is exactly what a procedure is for. When you find yourself assigning a variable and using it once, inline it.

## Transformations, I/O, and where AR models fit

**Transformations** are objects with no external side effects. **Form objects** are the canonical example: input is a model plus user-submitted params; output is a Boolean (valid?) plus the populated model. No persistence; that belongs in the procedure. **Permission objects** are another: input is a user and a resource; output is a Boolean. No queries triggered implicitly, no state changed; the procedure decides what to do with the result.

The decision rule for whether an abstraction belongs in this layer: does it *orchestrate*, or does it *answer*? A permission object answers: given this user and resource, can they act? A form object answers: are these params valid? An object that fetches records, delegates to another service, and enqueues a job orchestrates: that belongs in the procedure, written out explicitly. Extractions that answer belong here. Extractions that orchestrate belong in the procedure, written out explicitly.

A permission object in plain Ruby:

```ruby
class OrderPolicy
  def self.editable?(user, order)
    new(user, order).editable?
  end

  def initialize(user, order)
    @user  = user
    @order = order
  end

  def editable?
    @order.user_id == @user.id || @user.admin?
  end
end
```

The procedure calls it and owns the decision:

```ruby
class OrdersController < ApplicationController
  def update
    unless OrderPolicy.editable?(current_user, @order)
      return redirect_to @order, alert: "Not authorized"
    end

    if @order.update(order_params)
      redirect_to @order
    else
      render :edit
    end
  end
end
```

The policy answers one question. The procedure decides what happens next.

Form objects apply the same principle to validation. A form takes a cart and user-submitted params, validates them, and populates a new order. No persistence; that belongs in the procedure.

```ruby
class OrderForm
  include ActiveModel::Model
  attr_reader :order

  def initialize(cart, params = {})
    @order = Order.new(user: cart.user, cart: cart).tap { |o| o.assign_attributes(params) }
    super(params)
  end

  validates :quantity, numericality: { greater_than: 0 }
end
```

**I/O objects** are anything that touches external state. **Query objects** are I/O: they read from the database and belong in the procedure's explicit sequence, not inside a model method or scope. I/O deserves particular attention because I/O produces *artifacts*: records other flows read, emails users receive, jobs workers process. When I/O is hidden in a callback or a side-effecting scope, you lose the ability to trace which procedures produce which artifacts and what downstream work they trigger.

**ActiveRecord models** span transformations (validations, domain methods) and exactly *one* I/O boundary: database persistence. That's fine; validations and pure callbacks are part of the model's job. The problem is callbacks that trigger I/O side effects: sending an email, enqueuing a job, calling an external API. These create an implicit "always" contract: any caller that saves this model gets the side effects, whether it wants them or not. Web requests, background jobs, bulk imports, and test factories all fire the same callback. When that contract breaks down (and it will), the fix is `skip_callback`, which is the codebase admitting the "always" was never an invariant.

## Scenarios where this earns its keep

**Tests mirror the procedure.** When a procedure is explicit about its inputs and I/O, the test setup writes itself. Every I/O fetch in the procedure corresponds to an artifact you create in the setup. Every input corresponds to a param or fixture. There are no mystery guests. If a test fails because a record doesn't exist, that record should be findable in the procedure. An `after_create` callback that enqueues a job or touches a second table means your test setup needs records you can't predict from reading the procedure. Explicit procedures eliminate that surprise.

The `create` action in the Procedures section fetches `current_user` and `current_user.current_cart`. The test setup is a direct mirror:

```ruby
user = create(:user)          # current_user (procedure input)
create(:cart, user: user)     # current_user.current_cart (I/O in procedure)

post :create, params: { order: { quantity: 2 } }
```

**Multiple models in one action.** A create action that saves an order and a payment. A Form object holds references to both; the controller still reads as a flat sequence:

```ruby
class OrderWithPaymentForm
  include ActiveModel::Model
  attr_reader :order, :payment

  def initialize(cart, payment, params = {})
    @order   = Order.new(user: cart.user, cart: cart).tap { |o| o.assign_attributes(params[:order] || {}) }
    @payment = payment.tap { |p| p.assign_attributes(params[:payment] || {}) }
    super(params)
  end

  validate :order_valid, :payment_valid

  def order_valid
    errors.add(:order, "invalid") unless order.valid?
  end

  def payment_valid
    errors.add(:payment, "invalid") unless payment.valid?
  end
end

class OrdersController < ApplicationController
  def create
    cart  = current_user.current_cart
    @form = OrderWithPaymentForm.new(cart, Payment.new, order_params)
    if @form.valid?
      ActiveRecord::Base.transaction do
        @form.order.save!
        @form.payment.save!
        cart.complete!
      end
      NotifyPurchaserJob.perform_later(@form.order)
      NotifyMerchantJob.perform_later(@form.order)
      redirect_to @form.order
    else
      render :new
    end
  end
end
```

**Preventing N+1s.** Separating I/O from transformation makes N+1s structurally impossible. The procedure sequences: fetch all records once → transform each (no DB calls) → write results. When query logic and transformation logic are mixed, the query sneaks into the loop.

```ruby
class SendWeeklyDigestsJob < ApplicationJob
  def perform
    DigestableUsersQuery.new.call                        # I/O: one query
      .map  { |u| DigestBuilder.new(u) }                # Transformation: no DB calls
      .each { |d| DigestMailer.weekly(d).deliver_now }  # I/O: send
  end
end
```

**Moving non-essential work into jobs.** When a procedure lists its I/O explicitly, it's easy to see which operations must happen synchronously and which don't. Saving the order must happen before we can redirect. Notifying the purchaser and merchant don't need to block the response. When that work is hidden in a callback, extracting it means touching the model. When it's a line in the procedure, extracting it means swapping `deliver_now` for `perform_later`:

```ruby
ActiveRecord::Base.transaction do
  @form.order.save!   # essential
  cart.complete!      # essential
end
NotifyPurchaserJob.perform_later(@form.order)  # non-essential
NotifyMerchantJob.perform_later(@form.order)   # non-essential
```

The split is visible at the call site; moving work to a job is a one-line change.

## Getting there

The most direct first step: find a model callback that triggers a side effect (an email, a job, a third-party call) and move it inline into the controller. The controller gets longer. That length is the explicit declaration of work that was previously invisible. The instinct to re-extract it is the DRY instinct, and it's worth resisting before acting on it. Explicit side effects aren't noise; the explicitness is the point.

The Rails console belongs in this list too; it's part of the control plane and often overlooked. A developer running `Order.create(...)` against production has entered an orchestration context. If that model has I/O-mutating callbacks, the console carries the same risk as any script or job. When side effects are inline and visible, that risk is legible.

The opening problem was a change that looked local but touched five things. This structure doesn't eliminate complexity; it makes the five things visible. Open any procedure, read it top to bottom, and you know exactly what moves.
