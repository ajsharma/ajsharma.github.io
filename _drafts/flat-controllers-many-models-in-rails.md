---
layout: default
title: Flat Controllers, Many Models in Rails
---

# Flat Controllers, Many Models in Rails

The goal isn't to maintain a codebase. It's to evolve it — to introduce something that didn't exist before, to move an idea from concept to production before the window closes. Radical change is the work. The constraint on that work is almost always comprehension: you can't responsibly reshape what you don't understand.

That understanding is often missing. Not as a character flaw — codebases grow in ways that obscure their own behavior. A change that looks local turns out to touch five things. A callback fires somewhere downstream. A scope with a side effect triggers a query you didn't write. The more the system has grown, the more the gap between "what this code appears to do" and "what this code actually does" widens.

The testing experience makes the gap concrete. You want to validate your change, but you don't know what state the world needs to be in at the start. What records do you create? Which associations matter? You add factories until the test passes, then wonder if the setup reflects anything real. As the data model grows, the gap between "setup that makes tests pass" and "setup that reflects real-world behavior" widens. You end up with tests you can't fully trust — not because the assertions are wrong, but because you aren't sure the setup is right.

## The judgment test

Here's how you know something is hiding: open any procedure — a controller action, a job, a worker — and try to narrate it to a non-technical stakeholder in near real-time. Can you see all the inputs? Can you account for every mutation? If you can't, something is hiding. Callbacks, side-effecting models, logic tucked into scopes — all of them fail this test.

Passing it requires a deliberate choice about which layer owns what.

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

Web requests, jobs, and tasks are the application's **control plane** — the only layer whose job is orchestration. Naming this matters. Service objects fail long-term not because they're wrong in principle, but because they create a second control plane. Engineers can't tell whether orchestration belongs in the controller or the service. Services start calling jobs. Jobs call other services. You end up with two layers that both orchestrate, neither with full visibility.

This isn't a defense of long procedures. Every line in a procedure should earn its place as a business step. Noise — intermediate variables that just rename concepts, complex rules embedded inline — should be extracted. The question is what kind of extraction. A procedure that grows because it has ten genuine business steps is fine. A procedure cluttered with implementation detail that could be named and isolated is not. Extract the detail; keep the orchestration.

## Transformations, I/O, and where AR models fit

**Transformations** are objects with no external side effects. **Form objects** are the canonical example: input is a model plus user-submitted params; output is a Boolean (valid?) plus the populated model. No persistence — that belongs in the procedure. **Permission objects** are another: input is a user and a resource; output is a Boolean. No queries triggered implicitly, no state changed — the procedure decides what to do with the result.

The decision rule for whether an abstraction belongs in this layer: does it *orchestrate*, or does it *answer*? A permission object answers — given this user and resource, can they act? A form object answers — are these params valid? An object that fetches records, delegates to another service, and enqueues a job orchestrates — that belongs in the procedure, written out explicitly. Extractions that answer are signal. Extractions that orchestrate are a second control plane.

A permission object in plain Ruby:

```ruby
class OrderPolicy
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
def update
  policy = OrderPolicy.new(current_user, @order)
  unless policy.editable?
    redirect_to @order, alert: "Not authorized" and return
  end

  @form = OrderForm.new(@order, order_params)
  if @form.valid?
    @order.save!
    redirect_to @order
  else
    render :edit
  end
end
```

No framework, no DSL, no implicit query. The policy answers one question. The procedure decides what happens next.

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

**ActiveRecord models** span transformations (validations, domain methods) and exactly *one* I/O boundary: persistence. That's fine — validations and pure callbacks are part of the model's job. The problem is callbacks that trigger I/O side effects: sending an email, enqueuing a job, calling an external API. These create an implicit "always" contract — any caller that saves this model gets the side effects, whether it wants them or not. Web requests, background jobs, bulk imports, and test factories all fire the same callback. When that contract breaks down — and it will — the fix is `skip_callback`, which is the codebase admitting the "always" was never an invariant.

## Scenarios where this earns its keep

**Multiple models in one action.** A create action that saves an order and a payment. A Form object holds references to both; the controller still reads as a flat sequence:

```ruby
class OrderWithPaymentForm
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

def create
  @form = OrderWithPaymentForm.new(Order.new(user: current_user), Payment.new, order_params)
  if @form.valid?
    ActiveRecord::Base.transaction do
      @form.order.save!
      @form.payment.save!
    end
    redirect_to @form.order
  else
    render :new
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

**Moving non-essential work into jobs.** When a procedure lists its I/O explicitly, it's easy to see which operations must happen synchronously and which don't. Sending a confirmation email doesn't need to block the response. Updating an analytics aggregate doesn't need to happen before the redirect. When that work is hidden in a callback, extracting it means touching the model. When it's a line in the procedure, extracting it means swapping `deliver_now` for `perform_later`.

```ruby
def create
  @form = OrderForm.new(Order.new(user: current_user), order_params)
  if @form.valid?
    @form.order.save!                                      # essential — must happen now
    ConfirmationMailer.order(@form.order).deliver_later    # non-essential — can defer
    AnalyticsJob.perform_later("order.created", @form.order.id) # non-essential — can defer
    redirect_to @form.order
  else
    render :new
  end
end
```

The distinction between essential and non-essential I/O is visible in the procedure. Distributing the workflow is a local change.

**Tests mirror the procedure.** When a procedure is explicit about its inputs and I/O, the test setup writes itself. Every I/O fetch in the procedure corresponds to an artifact you create in the setup. Every input corresponds to a param or fixture. There are no mystery guests — if a test fails because a record doesn't exist, that record should be findable in the procedure. An `after_create` callback that enqueues a job or touches a second table means your test setup needs records you can't predict from reading the procedure. Explicit procedures eliminate that surprise: read the procedure top to bottom and you know exactly what to create.

```ruby
# Procedure — inputs and I/O fetches are visible
def create
  product = Product.find(params[:product_id])  # I/O fetch
  @form = OrderForm.new(Order.new(user: current_user, product: product), order_params)
  if @form.valid?
    @form.order.save!
    ConfirmationMailer.order(@form.order).deliver_later
    redirect_to @form.order
  else
    render :new
  end
end

# Test setup is a direct mirror
user    = create(:user)    # current_user — procedure input
product = create(:product) # Product.find  — I/O fetch in procedure

post :create, params: { product_id: product.id, order: { quantity: 2 } }
```

## Getting there

The most direct first step: find a model callback that triggers a side effect — an email, a job, a third-party call — and move it inline into the controller. The controller gets longer. That discomfort is informative. What you're feeling is the explicit declaration of work that was previously invisible. The instinct to re-extract it is the DRY instinct, and it's worth sitting with the resistance before acting on it. Explicit side effects aren't noise — the explicitness is the point.

This pattern earns its keep in proportion to the number of control planes in the system. In an app with a single controller layer and no background jobs, the benefits are modest. The argument gets sharper as the system grows: a customer-facing controller, an admin controller, an ops controller, background jobs, Rake tasks — all orchestrating against the same data. In that environment, a callback that fires on every save is a liability. An ops engineer writing a script to handle a support edge case shouldn't have to reason about whether it'll trigger customer-facing emails. When each control plane is explicit and side effects live in procedures, they don't.

The Rails console belongs in this list too — it's part of the control plane and often overlooked. A developer running `Order.create(...)` against production has entered an orchestration context. If that model has I/O-mutating callbacks, the console carries the same risk as any script or job. When side effects are inline and visible, that risk is legible.

A second concrete action: avoid creating a variable in a procedure unless it's used at least twice. A single-use variable is usually just an alias — a rename that adds a line without adding meaning. A variable used twice is different. It signals intentionality: you're holding a result to coordinate two subsequent steps, which is exactly what a procedure is for. When you find yourself assigning a variable and using it once, inline it. When a variable earns a second use, it's earning its name.

The opening problem was a change that looked local but touched five things. This structure doesn't eliminate complexity — it makes the five things visible. Confidence in a change becomes local: open the procedure, read it top to bottom, and you know exactly what moves.
