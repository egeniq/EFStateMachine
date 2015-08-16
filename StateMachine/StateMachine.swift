//
//  StateMachine.swift
//  Egeniq
//
//  Created by Johan Kool on 13/8/15.
//  Copyright (c) 2015 Egeniq. All rights reserved.
//

import Foundation

/** __A Simple State Machine__

This state machine is typically setup with an enum for its possible states, and an enum for its actions. The state
of the machine determines wether an action is allowed to run. The state of a machine can only be changed via an
action. The action handler returns the new state of the machine.

It is also possible to register multiple handlers that get run when certain state changes occur.

Sample code:

```
    private enum LoadState {
        case Start, Loading, Complete, Failed
    }

    private enum LoadAction {
        case Load, FinishLoading, Cancel
    }

    let machine = StateMachine<LoadState, LoadAction>(initialState: .Start)

    machine.registerAction(.Load, fromStates: [.Start, .Failed]) { (machine) -> StateMachineTests.LoadState in
        return .Loading
    }

    machine.registerAction(.FinishLoading, fromStates: [.Loading]) { (machine) -> StateMachineTests.LoadState in
        return .Complete // (or return .Failed if that's the case)
    }

    machine.registerAction(.Cancel, fromStates: [.Loading]) { machine in
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

*/
public class StateMachine<S, A where S: Hashable, A: Hashable> {

    /** An action handler

    - parameter machine: The machine running the handler
    - returns: The new state of the machine on completion of the handler
    */
    typealias ActionHandler = (machine: StateMachine<S, A>) -> S

    /** An state changed handler

    - parameter machine: The machine running the handler
    - parameter oldState: The previous state of the machine
    - parameter newState: The current state of the machine
    */
    typealias ChangeHandler = (machine: StateMachine<S, A>, oldState: S, newState: S) -> Void

    /// The initial state of the machine
    private (set) var initialState: S

    /// The current state of the machine
    private (set) var state: S {
        didSet(oldValue) {
            history.append(state)
            if UInt(history.count) == maxHistoryLength + 1 {
                history.removeAtIndex(0)
            }
            for (fromStates, toStates, changeHandler) in changes {
                if (fromStates == nil || fromStates?.contains(oldValue) == true) && (toStates == nil || toStates?.contains(state) == true) {
                    changeHandler(machine: self, oldState: oldValue, newState: state)
                }
            }
        }
    }

    /// A history of states the machine has been in from oldest to newest
    private (set) var history: [S]

    /// The maximum lenght of the history before it gets pruned
    private (set) var maxHistoryLength: UInt

    /** Create a new state machine

    - parameter initialState: The initial state of the machine
    - parameter maxHistoryLenght: The maximum lenght of the history before it gets pruned
    - returns: A state machine
    */
    init(initialState: S, maxHistoryLength: UInt = 10) {
        self.initialState = initialState
        self.state = initialState
        self.maxHistoryLength = maxHistoryLength
        if maxHistoryLength > 0 {
            self.history = [initialState]
        } else {
            self.history = []
        }
    }

    private var actions: [A: (Set<S>, ActionHandler)] = [:]

    /** Registers an action

    Registers a handler to run when performAction() is called. The action is only to be run if the state matches any of
    the states in the fromStates set. The handler must return a new state which will be set on the state machine after
    the handler has run.
    
    - Note: Only one handler can be registered for an action.
    
    - Warning: Make sure to avoid retain loops in your code. For example, if you setup the machine in a variable of your
    view controller and you then try to access that view controller from the actionHandler, you should use `[weak self]` 
    or `[unowned self]` for the handler.

    - parameter action: The action name
    - parameter fromStates: One or more states from which the action can be performed
    - parameter actionHandler: The handler to run when performing the action
    */
    func registerAction(action: A, fromStates: Set<S>, actionHandler: ActionHandler) {
        actions[action] = (fromStates, actionHandler)
    }

    /** Performs a registered action

    The action will only be performed if the machine is in one of the states for which the action was registered.

    - parameter action: The action to perform
    - returns: Returns the new state if the action was run, or nil if the action not run
    */
    func performAction(action: A) -> S? {
        if let actionTuple = actions[action] {
            if actionTuple.0.contains(state) {
                state = actionTuple.1(machine: self)
                return state
            }
        }
        return nil
    }

    private var changes: [(Set<S>?, Set<S>?, ChangeHandler)] = []

    /** Registers a handler to run on state change

    Registers a handler to run when the state of the machine changes. A change handler only gets run if the old state
    occurs in the fromStates set and the new state occurs in the toStates set. A nil set for either means any state 
    is acceptable.
    
    - Note: If an action set the same state as was already set, these handlers get run too.
    - Note: The change handlers will be run in the order they were registered.

    - parameter fromStates: The handler is only run if the old state is in this set. If nil, any state is acceptable.
    - parameter toStates: The handler is only run if the new state is in this set. If nil, any state is acceptable.
    - parameter changeHandler: The handler to run
    */
    func onChange(fromStates fromStates: Set<S>? = nil, toStates: Set<S>? = nil, changeHandler: ChangeHandler) {
        changes.append((fromStates, toStates, changeHandler))
    }
    
}
