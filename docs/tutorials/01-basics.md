# Basics

A Monomer application has four main components which are provided to the
`simpleApp` function:

- **Model**: contains the information the application uses.
- **Events**: generated from user action or system notifications.
- **Build UI function**: creates the UI using the current model.
- **Event handler**: reacts to events and can update the model, run asynchronous 
tasks and other actions.

We'll explore these components next.

**Note**: the code in this tutorial matches the one in `monomer-starter` and it
is also the same as in this package's `Tutorial00.hs`. Next tutorials will have
their own files matching the tutorial number; you can just copy the code over to
your project for testing.

## The model

The model represents the state of your application. Here you can store anything
that models your subject of interest. When the application starts, you need to
provide an initial model.

In the starter application, the model is simply a click counter. You can find it
in the Types.hs file.

```haskell
data AppModel = AppModel {
  _clickCount :: Int
} deriving (Eq, Show)
```

You can check the example applications to see some more complex models.

### Lenses

Monomer relies on the [lens](https://hackage.haskell.org/package/lens) library
to simplify the connection between the user model and the widgets that will be
displayed. You can find a short reference with enough information for what you
need to use the library [here](external/01-lenses.md).

#### Can I avoid using lenses?

Yes! All the included components have two versions, one for lenses and one for
values (with a **V** suffix). When using the **V** versions, you need to provide
the current value and an event that will be generated when the value managed by
the widget changes. Once you receive the event, you can update your model using
your preferred mechanism. Since the widget receives the value you provide, if
you don't update the model it will keep displaying the previous value.

In general, unless you need to perform some kind of validation (or you really
don't like lenses), the non **V** version is simpler and avoids boilerplate.

## Events type

The events type represents the different actions your event handler can react
to. It is an algebraic data type whose values may take arguments or not. A click
event does not need arguments, but onChange events require receiving an argument
matching the type of the content the widget handles.

```haskell
data AppEvent
  = AppInit
  | AppIncrease
  deriving (Eq, Show)
```

## Creating the UI

The build UI function takes care of creating the widget tree. Whenever the model
changes this function will be invoked and a new version of the widget tree will
be created, that will then be [merged](../reference/01-merge-process.md) with
the previous version.

The starter application includes the following snippet:

```haskell
buildUI
  :: WidgetEnv AppModel AppEvent
  -> AppModel
  -> WidgetNode AppModel AppEvent
buildUI wenv model = widgetTree
```

First of all, you'll see the type signature. You don't really need to include
it, but in general its preferable to have clearer compiler errors when a typo
or similar occurs. Both `WidgetEnv` (environment information that can be used
when building the UI) and `WidgetNode` (the result of building the UI) need to
be provided the type of your model and the type of your events.

Next, you'll see the parameters the function receives:

- **wenv**: short for Widget Environment, this includes information about the OS,
window size, input status, focus and several other items.
- **model**: the current state.

Finally, a WidgetNode is returned. The function expects a node, which can be a
single widget or a more complex layout.

We'll explore some basic widgets now.

### Layout

The two most common widgets for layout are `hstack` and `vstack`. These allow
stacking widgets next to each other in horizontal or vertical position, trying
to satisfy the size requests of each of them.

Back to the starter app, you can see both being used:

```haskell
buildUI wenv model = widgetTree where
  widgetTree = vstack [
      label "Hello world",
      hstack [
        label $ "Click count: " <> showt (model ^. clickCount),
        spacer,
        button "Increase count" AppIncrease
      ]
    ]
```

In the simplest use case, stack receives a list of widgets that will be laid out
either horizontally or vertically (the h or v indicate the main axis).

Stack will assign the maximum available space for the secondary axis. In the
example, the children of vstack will get same width vstack gets (the window
width, in this case), but will be assigned vertical space according to what they
requested.

Inside hstack you'll notice the use of `spacer`. This just adds a small space
between two widgets. Simple but very useful! In case you want to take as much
space as available (for instance, you want one button on the left, one on the
right and space in the middle) you can use `filler`.

### Basic widgets

In the example you can see `label` and `button`, two basic building blocks which
are useful in most applications.

#### Label

As expected, label is used to display text. More specifically, it displays
[Text](https://hackage.haskell.org/package/text) instances. There is also
`labelS`, which can be used for instances of `Show`, such as numbers or custom
types, without having to convert first to Text. If you need to display a
`String` instance, it's better to use `Text.pack` to avoid having `"` displayed.

Most widgets support a basic version, such as `label`, and a configurable
version which is denoted by a trailing `_`. In the case of `label_`, some of the
config options are:

- **multiLine**: to split the text into multiple lines if width is not enough.
- **ellipsis**: to show ellipse when text overflows instead of just cutting it.

For example:

```haskell
label_ "This is\nmultiline text" [multiLine, ellipsis]
```

#### Button

The button widget provides a basic interaction block for users. To construct it,
it needs a caption and an event as defined in [Events type](#events-type).

It supports the same configuration options as label (multiline, ellipsis, etc)
plus some extra options for other possible events accessible with `button_`:

- onClick: in case you want to generate more than one event.
- onFocus: raises an event when the button gains focus.
- onBlur: raises an event when the button loses focus.

All widgets that can be focused provide the onFocus and onBlur events.

## Event handling

In the starter app, you can see the following event handler:

```haskell
handleEvent
  :: WidgetEnv AppModel AppEvent
  -> WidgetNode AppModel AppEvent
  -> AppModel
  -> AppEvent
  -> [AppEventResponse AppModel AppEvent]
handleEvent wenv node model evt = case evt of
  AppInit -> []
  AppIncrease -> [Model (model & clickCount +~ 1)]
```

As in the build UI function, it's usually better to declare the types. Again we
have WidgetEnv and WidgetNode, but we now also have `AppEventResponse`, which
takes the same two type parameters (model and event types).

Looking at the parameters, we see:

- **wenv**: the Widget Environment.
- **node**: the current node. In general you will not use this parameter, but it
allows inspecting the underlying tree structure.
- **model**: the current state.
- **evt**: the event to handle.

The usual process consists on matching on the expected events (defined in your
events type) and returning a list of responses for the runtime to process.

In the example we use the `Model` response, which sets the new state of the
application (you can check the [lens](external/01-lenses.md) tutorial to better
understand those operators). If the model changed, this will trigger a call to
the build UI function.