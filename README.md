# MisoDispatchWorkItemKeeper

## SwiftUI package to cancel async operations on View disappearance

As defined in [To SwiftUI or Not SwiftUI][4] blog post, one of the major problem with SwiftUI's ways is there is no real way to store a `DispatchWorkItem` in order to cancel it when a view disappears. The problem with SwiftUI model is you cannot set a `@State` variable while it's in rendering code. So you must do it afterwards. So if you want to execute something asynchronously at this point, you cannot store anything to be able to cancel it. And if your `View` disappears before your asynchronous code executes, your application will crash, as the view is not visible anymore.

This can also be extended to `.onAppear` code when you are in a `GeometryReader`, so, against all odds, you cannot set states there either. And you cannot store a `GeometryProxy` as its state can also disappear past its usage.

Enter the `DispatchWorkItemKeeper`, which allows you to keep a `DispatchWorkItem` for the duration of a View's lifetime.

## Usage

```
import MisoDispatchWorkItemKeeper

struct MyView: View {
    @State var dispatchWorkItemKeeper = DispatchWorkItemKeeper()
    @State var initialFrame = CGRect()

    var body: some View {
        GeometryReader { geometry in
            Color.clear.onAppear {
                let globalFrame = geometry.frame(in: .global)
                DispatchQueue.main.async(execute: self.dispatchWorkItemKeeper.keep(DispatchWorkItem {
                    self.initialFrame = globalFrame
                }))
            }
        }.onDisappear {
            self.dispatchWorkItemKeeper.invalidateAll()
        }
    }
}
```

In this simple example, the `initialFrame` state cannot be set directly in the `GeometryReader`. It cannot be set in `onAppear` either, as both of these are run during rendering. But that view might be short-lived, and disappear before the `async` has time to be executed. So we keep the variable in the keeper.

The keeper must be stored in a `@State` in itself, as the view's struct is short lived, and can be recreated as many times as needed. However, the `@State` will be preserved across instantiations.

## Caveats

The code does not do any kind of housekeeping. As such, if you create a new async code 60 times per second, you might have a memory problem after a few minutes worth of execution. You are responsible for invalidating your set. Maybe you can provide a patch to improve these special cases.


## Colophon

[The official address for this package][0]

[The git / package url][1]

This package is created and maintained by [Misoservices Inc.][2] and is [licensed under the BSL-1.0: Boost Software License - Version 1.0][3].


[0]: https://github.com/Misoservices/MisoDispatchWorkItemKeeper
[1]: https://github.com/Misoservices/MisoDispatchWorkItemKeeper.git
[2]: https://misoservices.com
[3]: https://choosealicense.com/licenses/bsl-1.0/
[4]: https://dev.misoservices.com/blog/to-swiftui-or-not-to-swiftui/
