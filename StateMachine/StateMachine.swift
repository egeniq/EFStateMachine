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

    machine.registerAction(.Load, fromStates: [.Start, .Failed], toStates: [.Loading]) { (machine) -> StateMachineTests.LoadState in
        return .Loading
    }

    machine.registerAction(.FinishLoading, fromStates: [.Loading], toStates: [.Complete, .Failed]) { (machine) -> StateMachineTests.LoadState in
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
    public typealias ActionHandler = (machine: StateMachine<S, A>) -> S

    /** An state changed handler

    - parameter machine: The machine running the handler
    - parameter oldState: The previous state of the machine
    - parameter newState: The current state of the machine
    */
    public typealias ChangeHandler = (machine: StateMachine<S, A>, oldState: S, newState: S) -> Void

    /// The initial state of the machine
    public private (set) var initialState: S

    /// The current state of the machine
    public private (set) var state: S {
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
    public private (set) var history: [S]

    /// The maximum lenght of the history before it gets pruned
    public private (set) var maxHistoryLength: UInt

    /** Create a new state machine

    - parameter initialState: The initial state of the machine
    - parameter maxHistoryLenght: The maximum lenght of the history before it gets pruned
    - returns: A state machine
    */
    public init(initialState: S, maxHistoryLength: UInt = 10) {
        self.initialState = initialState
        self.state = initialState
        self.maxHistoryLength = maxHistoryLength
        if maxHistoryLength > 0 {
            self.history = [initialState]
        } else {
            self.history = []
        }
    }

    private var actions: [A: (Set<S>, Set<S>, ActionHandler)] = [:]

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
    - parameter toStates: The states that the action handler may return
    - parameter actionHandler: The handler to run when performing the action
    */
    public func registerAction(action: A, fromStates: Set<S>, toStates: Set<S>, actionHandler: ActionHandler) {
        actions[action] = (fromStates, toStates, actionHandler)
    }

    /** Performs a registered action

    The action will only be performed if the machine is in one of the states for which the action was registered. If you specify a delay the action will be performed on the main queue.
    
    - Note: If you don't specify a delay, you must guarantee that the method is not called from within an action handler registered with the machine.

    - parameter action: The action to perform
    - parameter delay: The delay in seconds after which the action should be performed
    - returns: Returns the new state if the action was run, or nil if the action is not (yet) run
    */
    public func performAction(action: A, afterDelay delay: NSTimeInterval? = nil) -> S? {
        if let delay = delay {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))),
                dispatch_get_main_queue(), { [weak self] in
                    self?.performAction(action)
            })
            return nil
        }

        if actionHandlerRunning {
            print("WARNING: The action \"\(action)\" is ignored because there is still another unfinished action. If you called performAction (indirectly) from within an action handler, consider setting a delay.")
            return nil
        }

        if let (fromStates, toStates, actionHandler) = actions[action] {
            if fromStates.contains(state) {
                actionHandlerRunning = true
                let newState = actionHandler(machine: self)
                actionHandlerRunning = false
                if toStates.contains(newState) {
                    state = newState
                    return state
                }
                print("WARNING: The action handler for \"\(action)\" returned the state \"\(newState)\" but the state machine expects one of these states: \(toStates). State kept at \"\(state)\".")
                return nil
            }
        }
        return nil
    }

    private var actionHandlerRunning: Bool = false

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
    public func onChange(fromStates fromStates: Set<S>? = nil, toStates: Set<S>? = nil, changeHandler: ChangeHandler) {
        changes.append((fromStates, toStates, changeHandler))
    }

}

public extension StateMachine {

    var flowdiagramRepresentation: String {
        let representation = Flowdiagram(machine: self)
        return representation.description
    }

    func saveFlowdiagramRepresentationToPath(path: String) throws {
        try flowdiagramRepresentation.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    }

}

class Flowdiagram<S, A where S: Hashable, A: Hashable>: CustomStringConvertible {

    let machine:  StateMachine<S, A>

    init(machine: StateMachine<S, A>) {
        self.machine = machine
    }

    var description: String {
        nodes = []
        links = []

        let a = machine.initialState
        addState(a)

        for (action, (fromStates, toStates, _)) in machine.actions {
            fromStates.forEach() { fromState in
                let fromStateIndex = addState(fromState)
                toStates.forEach() { toState in
                    let toStateIndex = addState(toState)
                    addAction(action, fromIndex: fromStateIndex, toIndex: toStateIndex)
                }
            }
        }

        let nodesStr = nodes.map({ (index: Int, state: S?, action: A?) in
            if let state = state {
                return "    \(index) [label=\"\(state)\", shape=box]\n"
            } else if let action = action {
                return "    \(index) [label=\"\(action)\", shape=oval]\n"
            }
            return "    \n"
        }).joinWithSeparator("")

        let linksStr = links.map({ (from: Int, to: Int, hasArrow: Bool) in
            if hasArrow {
                return "    \(from) -> \(to)\n"
            } else {
                return "    \(from) -> \(to) [arrowhead=none]\n"
            }
        }).joinWithSeparator("")

        return "digraph {\n    graph [rankdir=TB]\n    \n    0 [label=\"\", shape=plaintext]\n    0 -> 1\n    \n    # node\n\(nodesStr)\n    \n    # links\n\(linksStr)\n}"
    }

    private var nodes: [(Int, S?, A?)] = []
    private var links: [(Int, Int, Bool)] = []

    private func addState(state: S) -> Int {
        let filtered = nodes.filter() { (index: Int, aState: S?, action: A?) in
            return aState == nil ? false : state == aState!
        }
        if let (index, _, _) = filtered.first {
            return index
        } else {
            let index = nodes.count + 1
            nodes.append((index, state, nil))
            return index
        }
    }

    private func addAction(action: A) -> Int {
        let filtered = nodes.filter() { (index: Int, aState: S?, anAction: A?) in
            return anAction == nil ? false : action == anAction!
        }
        if let (index, _, _) = filtered.first {
            return index
        } else {
            let index = nodes.count + 1
            nodes.append((index, nil, action))
            return index
        }
    }

    private func addAction(action: A, fromIndex: Int, toIndex: Int) {
        let actionIndex = addAction(action)
        addLink(fromIndex: fromIndex, toIndex: actionIndex, hasArrow: false)
        addLink(fromIndex: actionIndex, toIndex: toIndex, hasArrow: true)
    }

    private func addLink(fromIndex fromIndex: Int, toIndex: Int, hasArrow: Bool) {
        if !links.contains({ (from: Int, to: Int, arrow: Bool) in
            return from == fromIndex && to == toIndex && arrow == hasArrow
        }) {
            links.append((fromIndex, toIndex, hasArrow))
        }
    }

}

