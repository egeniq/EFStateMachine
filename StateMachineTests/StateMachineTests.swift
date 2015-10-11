//
//  StateMachineTests.swift
//  StateMachineTests
//
//  Created by Johan Kool on 15/8/15.
//  Copyright © 2015 Egeniq. All rights reserved.
//

import XCTest
import StateMachine

class StateMachineTests: XCTestCase {

    private enum TestLoadState: String {
        case Empty, Loading, Partial, Complete, Failed
    }

    private enum TestLoadAction: String {
        case Load, FinishLoading, LoadMore, Cancel, Reset, Mystery
    }

    private var loadMachine: StateMachine<TestLoadState, TestLoadAction>!

    private func setupLoadMachine(length length: UInt = 3) -> StateMachine<TestLoadState, TestLoadAction> {
        let machine = StateMachine<TestLoadState, TestLoadAction>(initialState: .Empty, maxHistoryLength: length)

        machine.registerAction(.Load, fromStates: [.Empty], toStates: [.Loading]) { (machine) -> StateMachineTests.TestLoadState in
            return .Loading
        }

        machine.registerAction(.FinishLoading, fromStates: [.Loading], toStates: [.Complete, .Failed]) { (machine) -> StateMachineTests.TestLoadState in
            return .Complete
        }

        machine.registerAction(.Cancel, fromStates: [.Loading], toStates: [.Empty]) { (machine) -> StateMachineTests.TestLoadState in
            return machine.history[machine.history.count - 2]
        }

        machine.registerAction(.Reset, fromStates: [.Complete, .Failed], toStates: [.Empty]) { (machine) -> StateMachineTests.TestLoadState in
            return .Empty
        }

        // #1
        machine.onChange { [weak self] (machine, oldState, newState) -> Void in
            let callback: (Int, StateMachine<TestLoadState, TestLoadAction>, TestLoadState, TestLoadState) = (1, machine, oldState, newState)
            self?.recordedCallBacks.append(callback)
        }

        // #2
        machine.onChange(fromStates: [.Loading]) { [weak self] (machine, oldState, newState) -> Void in
            let callback: (Int, StateMachine<TestLoadState, TestLoadAction>, TestLoadState, TestLoadState) = (2, machine, oldState, newState)
            self?.recordedCallBacks.append(callback)
        }

        // #3
        machine.onChange(toStates: [.Complete]) { [weak self] (machine, oldState, newState) -> Void in
            let callback: (Int, StateMachine<TestLoadState, TestLoadAction>, TestLoadState, TestLoadState) = (3, machine, oldState, newState)
            self?.recordedCallBacks.append(callback)
        }

        return machine
    }

    private var recordedCallBacks: [(Int, StateMachine<TestLoadState, TestLoadAction>, TestLoadState, TestLoadState)] = []

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
        XCTAssertEqual(loadMachine.state, TestLoadState.Empty)
    }

    func testValidStateChange() {
        // Check returned state
        let state = loadMachine.performAction(.Load)
        XCTAssertTrue(state == TestLoadState.Loading)

        // Check reported state
        XCTAssertEqual(loadMachine.state, TestLoadState.Loading)
    }

    func testInvalidStateChange() {
        // Check returned state
        let state = loadMachine.performAction(.FinishLoading)
        XCTAssertTrue(state == nil)

        // Check reported state
        XCTAssertEqual(loadMachine.state, TestLoadState.Empty)
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

    func testZeroLenghtHistoryMachine() {
        let zeroMachine = setupLoadMachine(length: 0)

        XCTAssertEqual(zeroMachine.history.count, 0)
        zeroMachine.performAction(.Load)
        zeroMachine.performAction(.FinishLoading)
        XCTAssertEqual(zeroMachine.history.count, 0)

        zeroMachine.performAction(.Reset)
        XCTAssertEqual(zeroMachine.history.count, 0)

        zeroMachine.performAction(.Load)
        zeroMachine.performAction(.FinishLoading)
        XCTAssertEqual(zeroMachine.history.count, 0)
    }

    func testInvalidStateReturned() {
        loadMachine.registerAction(.Load, fromStates: [.Empty, .Failed], toStates: [.Loading]) { (machine) -> StateMachineTests.TestLoadState in
            return .Failed
        }

        XCTAssertTrue(loadMachine.performAction(.Load) == nil)
    }

    func testUnregisteredAction() {
        XCTAssertTrue(loadMachine.performAction(.Mystery) == nil)
    }


    func testFlowdiagram() {
        let diagram = loadMachine.flowdiagramRepresentation
        XCTAssertEqual(diagram, "digraph {\n    graph [rankdir=TB]\n    \n    0 [label=\"\", shape=plaintext]\n    0 -> 1\n    \n    # node\n    1 [label=\"Empty\", shape=box]\n    2 [label=\"Complete\", shape=box]\n    3 [label=\"Reset\", shape=oval]\n    4 [label=\"Failed\", shape=box]\n    5 [label=\"Loading\", shape=box]\n    6 [label=\"Load\", shape=oval]\n    7 [label=\"FinishLoading\", shape=oval]\n    8 [label=\"Cancel\", shape=oval]\n\n    \n    # links\n    2 -> 3 [arrowhead=none]\n    3 -> 1\n    4 -> 3 [arrowhead=none]\n    1 -> 6 [arrowhead=none]\n    6 -> 5\n    5 -> 7 [arrowhead=none]\n    7 -> 2\n    7 -> 4\n    5 -> 8 [arrowhead=none]\n    8 -> 1\n\n}")

    }

    var infoLabel: UILabel = UILabel()

    func testSampleCode() {
        enum LoadState: String {
            case Empty
            case Loading
            case Complete
            case Failed
        }

        enum LoadAction: String {
            case Load
            case FinishLoading
            case Cancel
            case Reset
        }

        let machine = StateMachine<LoadState, LoadAction>(initialState: .Empty)

        machine.registerAction(.Load, fromStates: [.Empty, .Failed], toStates: [.Loading]) { (machine) -> LoadState in
            return .Loading
        }

        machine.registerAction(.FinishLoading, fromStates: [.Loading], toStates: [.Complete, .Failed]) { (machine) -> LoadState in
            return .Complete // (or return .Failed if that's the case)
        }

        machine.registerAction(.Reset, fromStates: [.Complete, .Failed], toStates: [.Empty]) { (machine) -> LoadState in
            return .Empty
        }

        machine.registerAction(.Cancel, fromStates: [.Loading], toStates: [.Empty, .Failed]) { (machine) -> LoadState in
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

        do {
            try machine.saveFlowdiagramRepresentationToPath("/path/to/example-flow-diagram.dot")
        } catch let error {
            NSLog("Could not save flowdiagram: \(error)")
        }
    }
}
