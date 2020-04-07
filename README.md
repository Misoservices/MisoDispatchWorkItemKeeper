# MisoDispatchWorkItemKeeper

## Swift package to cancel async operations on class/struct deletion

![Platform](https://img.shields.io/badge/platform-iOS%2013%20%7C%20macOS%2010.15%20%7C%20tvOS%2013-lightgrey) ![Swift](https://github.com/Misoservices/MisoDispatchWorkItemKeeper/workflows/Swift/badge.svg) [![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=Misoservices_MisoDispatchWorkItemKeeper&metric=alert_status)](https://sonarcloud.io/dashboard?id=Misoservices_MisoDispatchWorkItemKeeper) [![Codacy Badge](https://api.codacy.com/project/badge/Grade/fb3979da0aa04eb6900c7ff2f22ae87a)](https://www.codacy.com/gh/Misoservices/MisoDispatchWorkItemKeeper?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=Misoservices/MisoDispatchWorkItemKeeper&amp;utm_campaign=Badge_Grade) [![codecov](https://codecov.io/gh/Misoservices/MisoDispatchWorkItemKeeper/branch/master/graph/badge.svg)](https://codecov.io/gh/Misoservices/MisoDispatchWorkItemKeeper)

## SwiftUI's View disappearance

As defined in [To SwiftUI or Not SwiftUI][4] blog post, one of the major problem with SwiftUI's ways is there is no real way to store a `DispatchWorkItem` in order to cancel it when a view disappears. The problem with SwiftUI model is you cannot set a `@State` variable while it's in rendering code. So you must do it afterwards. So if you want to execute something asynchronously at this point, you cannot store anything to be able to cancel it. And if your `View` disappears before your asynchronous code executes, your application will crash, as the view is not visible anymore.

This can also be extended to `.onAppear` code when you are in a `GeometryReader`, so, against all odds, you cannot set states there either. And you cannot store a `GeometryProxy` as its state can also disappear past its usage.

Enter the `DispatchWorkItemKeeper`, which allows you to keep a `DispatchWorkItem` for the duration of a View's lifetime.

### Usage

```
import MisoDispatchWorkItemKeeper

struct MyView: View {
    @State var dispatchWorkItemKeeper = DispatchWorkItemKeeper()
    @State var initialFrame = CGRect()

    var body: some View {
        GeometryReader { geometry in
            Color.clear.onAppear {
                let globalFrame = geometry.frame(in: .global)
                self.dispatchWorkItemKeeper.async(in: DispatchQueue.main) {
                    self.initialFrame = globalFrame
                }
            }
        }
    }
}
```

In this simple example, the `initialFrame` state cannot be set directly in the `GeometryReader`. It cannot be set in `onAppear` either, as both of these are run during rendering. But that view might be short-lived, and disappear before the `async` has time to be executed. So we keep the variable in the keeper.

The keeper must be stored in a `@State` in itself, as the view's struct is short lived, and can be recreated as many times as needed. However, the `@State` will be preserved across instantiations.

### Very safe usage

The jury is on the fence on `@State` life expectancy versus `.onAppear` and `.onDisappear` usage. So far, I have not seen any reason to use the very safe version, but this might end up being one of the very few edge cases we have not encountered in our application.

The goal of this version is to have pending tasks run only when the `View` is on screen, and not merely when it's loaded.

```
import MisoDispatchWorkItemKeeper

struct MyView: View {
    @State var dispatchWorkItemKeeper = DispatchWorkItemKeeper(.manual)
    @State var initialFrame = CGRect()

    var body: some View {
        GeometryReader { geometry in
            Color.clear.onAppear {
                let globalFrame = geometry.frame(in: .global)
                self.dispatchWorkItemKeeper.async(in: DispatchQueue.main) {
                    self.initialFrame = globalFrame
                }
            }
        }.onAppear {
            self.dispatchWorkItemKeeper.start()
        }.onDisappear {
            self.dispatchWorkItemKeeper.stop()
        }
    }
}
```


## Using the code in Swift (not SwiftUI)

Although the system was created with a simple SwiftUI task in mind, the code was modified to be usable in other class, and with multiple dispatch queues at the same time. Also, there are functionalities to limit memory leaks and complete execution before class is deleted. Hopefully, it will help people have less random issues with their code.


## Caveats

This code was created for simplicity in mind. It will not be much of a bottleneck for most simple cases, but it is not meant to provide a solution on extreme cases, such as algorithmic massive parallelism or very long operations. You should profile after integrating a new API, especially one that marshalls dispatching of work items.

There might be some bugs. Version 1.0.0 should be pretty much bug-free, and didn't really need any unit testing for the very limited use cases it covers. From Version 1.1.0 onwards, the code is massively more complex, has more inner interaction, every keeper has its own `DispatchQueue` and I am sure it's easy to uncover edge cases to make it crash. Please keep the bug reports coming!


## Version History

### 1.1.0 (2020-04-06)

- OSS-16 Make the keeper multithreaded and add extra basic features
  - OSS-19 Update Struct/Class paradigm of the Keeper to make it safe and not rely on a static dictionary
  - OSS-20 Automatically clean up on multiple additions
  - OSS-21 Code bound to a DispatchQueue, make operations asynchronous
  - OSS-22 Work Items needs to be done executing before destructor exits
  - OSS-23 Allow cancellation or not of Work Items at destruction
  - OSS-24 Manual Init/Deinit for cases where the Keeper outlasts the usage
- OSS-17 Add unit testing
- OSS-18 Add CI

### 1.0.0 - Initial version (2020-03-04)

- OSS-6 Create DispatchWorkItemKeeper


## Colophon

[The official address for this package][0]

[The git / package url][1]

This package is created and maintained by [Misoservices Inc.][2] and is [licensed under the BSL-1.0: Boost Software License - Version 1.0][3].


[0]: https://github.com/Misoservices/MisoDispatchWorkItemKeeper
[1]: https://github.com/Misoservices/MisoDispatchWorkItemKeeper.git
[2]: https://misoservices.com
[3]: https://choosealicense.com/licenses/bsl-1.0/
[4]: https://dev.misoservices.com/blog/to-swiftui-or-not-to-swiftui/
