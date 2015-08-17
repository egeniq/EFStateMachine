EFStateMachine.swift
====================

[![Language: Swift](https://img.shields.io/badge/lang-Swift-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://raw.githubusercontent.com/Egeniq/EFStateMachine/master/LICENSE)
[![CocoaPods](https://img.shields.io/cocoapods/v/EFStateMachine.svg?style=flat)](http://cocoapods.org)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

__A Simple State Machine__

This state machine is typically setup with an enum for its possible states, and an enum for its actions. The state
of the machine determines wether an action is allowed to run. The state of a machine can only be changed via an
action. The action handler returns the new state of the machine.

It is also possible to register multiple handlers that get run when certain state changes occur.

Sample code:

```swift
    private enum LoadState {
        case Start, Loading, Complete, Failed
    }

    private enum LoadAction {
        case Load, FinishLoading, Cancel
    }

    let machine = StateMachine<LoadState, LoadAction>(initialState: .Start)

    machine.registerAction(.Load, fromStates: [.Start, .Failed], toStates: [.Loading) { (machine) -> StateMachineTests.LoadState in
        return .Loading
    }

    machine.registerAction(.FinishLoading, fromStates: [.Loading], toStates: [.Complete, .Failed) { (machine) -> StateMachineTests.LoadState in
        return .Complete // (or return .Failed if that's the case)
    }

    machine.registerAction(.Cancel, fromStates: [.Loading], toStates: [.Start, .Failed]) { machine in
        return machine.history[machine.history.count - 2]
    }

    machine.onChange(toStates: [.Complete]) { [unowned self] (machine, oldState, newState) -> Void in
        self.infoLabel.text = "Complete!"
    }

    // Start loading
    machine.performAction(.Load) // returns .Loading

    // Loading finished
    machine.performAction(.FinishLoading) // returns .Complete and updates infoLabel to "Complete!"

    // Try loading again (an invalid action)
    machine.performAction(.Load) // returns nil
	

