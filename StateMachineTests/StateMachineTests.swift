//
//  StateMachineTests.swift
//  StateMachineTests
//
//  Created by Johan Kool on 15/8/15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

import XCTest
@testable import StateMachine

class StateMachineTests: XCTestCase {

    private enum LoadState {
        case Empty, Loading, Partial, Complete, Failed
    }

    private enum LoadAction {
        case Load, FinishLoading, LoadMore, Cancel, Reset
    }

    private var loadMachine: StateMachine<LoadState, LoadAction>!

    private func setupLoadMachine() -> StateMachine<LoadState, LoadAction> {
        let machine = StateMachine<LoadState, LoadAction>(initialState: .Empty, maxHistoryLength: 3)

        machine.registerAction(.Load, fromStates: [.Empty, .Failed]) { (machine) -> StateMachineTests.LoadState in
            return .Loading
        }

        machine.registerAction(.FinishLoading, fromStates: [.Loading]) { (machine) -> StateMachineTests.LoadState in
            return .Complete
        }

        machine.registerAction(.Cancel, fromStates: [.Loading]) { (machine) -> StateMachineTests.LoadState in
            return machine.history[machine.history.count - 2]
        }

        machine.registerAction(.Reset, fromStates: [.Complete, .Failed]) { (machine) -> StateMachineTests.LoadState in
            return .Empty
        }

        // #1
        machine.onChange { [weak self] (machine, oldState, newState) -> Void in
            self?.recordedCallBacks.append((1, machine, oldState, newState))
        }

        // #2
        machine.onChange(fromStates: [.Loading]) { [weak self] (machine, oldState, newState) -> Void in
            self?.recordedCallBacks.append((2, machine, oldState, newState))
        }

        // #3
        machine.onChange(toStates: [.Complete]) { [weak self] (machine, oldState, newState) -> Void in
            self?.recordedCallBacks.append((3, machine, oldState, newState))
        }

        return machine
    }

    private var recordedCallBacks: [(Int, StateMachine<LoadState, LoadAction>, LoadState, LoadState)] = []

    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        loadMachine = setupLoadMachine()
        recordedCallBacks = []
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        loadMachine  = nil
        recordedCallBacks.removeAll()

        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(loadMachine.state, LoadState.Empty)
    }

    func testValidStateChange() {
        // Check returned state
        let state = loadMachine.performAction(.Load)
        XCTAssertEqual(state, LoadState.Loading)

        // Check reported state
        XCTAssertEqual(loadMachine.state, LoadState.Loading)
    }

    func testInvalidStateChange() {
        // Check returned state
        let state = loadMachine.performAction(.FinishLoading)
        XCTAssertEqual(state, nil)

        // Check reported state
        XCTAssertEqual(loadMachine.state, LoadState.Empty)
    }

    func testOnChangeCallbacks() {
        XCTAssertEqual(recordedCallBacks.count, 0)

        loadMachine.performAction(.Load)

        // #1 should fire
        XCTAssertEqual(recordedCallBacks.count, 1)
        XCTAssertEqual(recordedCallBacks[0].0, 1)

        loadMachine.performAction(.FinishLoading)

        // #1, #2 and #3 should fire in that order
        XCTAssertEqual(recordedCallBacks.count, 4)
        XCTAssertEqual(recordedCallBacks[1].0, 1)
        XCTAssertEqual(recordedCallBacks[2].0, 2)
        XCTAssertEqual(recordedCallBacks[3].0, 3)
    }

    func testHistoryPruning() {
        XCTAssertEqual(loadMachine.history.count, 1)
        loadMachine.performAction(.Load)
        loadMachine.performAction(.FinishLoading)
        XCTAssertEqual(loadMachine.history.count, 3)

        loadMachine.performAction(.Reset)
        XCTAssertEqual(loadMachine.history.count, 3)

        loadMachine.performAction(.Load)
        loadMachine.performAction(.FinishLoading)
        XCTAssertEqual(loadMachine.history.count, 3)
    }

}
