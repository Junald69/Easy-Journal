import XCTest
@testable import EasyJournal

final class MonthlyNavigationTests: XCTestCase {
    private func makeRouter() -> Router {
        let router = Router()
        router.open(.monthlyLog(monthKey: "2026-10"))
        router.beginGuardingMonthlyNavigation()
        return router
    }

    private func complete(_ router: Router) throws {
        let request = try XCTUnwrap(router.pageLeaveRequest)
        let authorization = PageLeaveAuthorization.makeForTests(
            destination: request.destination, requestToken: request.token)
        XCTAssertTrue(router.resolveGuardedOpen(request.destination,
            requestToken: request.token, resolution: .passed(authorization)))
    }

    func testSidesRemainGuardedAndRejectReusedAuthorization() throws {
        let router = makeRouter()
        router.open(.monthlyTracker(monthKey: "2026-10"))
        let request = try XCTUnwrap(router.pageLeaveRequest)
        let auth = PageLeaveAuthorization.makeForTests(destination: request.destination, requestToken: request.token)
        XCTAssertTrue(router.resolveGuardedOpen(request.destination, requestToken: request.token, resolution: .passed(auth)))
        router.open(.monthlyLog(monthKey: "2026-10"))
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-10"))
        XCTAssertNotNil(router.pageLeaveRequest)
        XCTAssertFalse(router.resolveGuardedOpen(request.destination, requestToken: request.token, resolution: .passed(auth)))
        try complete(router)
        router.open(.daily(dateKey: "2026-10-27"))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        XCTAssertNotNil(router.pageLeaveRequest)
    }

    func testRightMonthChangePreservesSideAndAuthorizationIsOneTime() throws {
        let router = makeRouter()
        router.open(.monthlyTracker(monthKey: "2026-10"))
        try complete(router)
        router.requestMonth("2026-11")
        let request = try XCTUnwrap(router.monthRequest)
        router.clearMonthRequest()
        let auth = MonthMoveAuthorization.makeForTests(monthKey: request.monthKey, requestToken: request.token)
        XCTAssertTrue(router.commitDisplayedMonth(request.monthKey, requestToken: request.token, authorization: auth))
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-11"))
        XCTAssertFalse(router.commitDisplayedMonth(request.monthKey, requestToken: request.token, authorization: auth))
        router.open(.monthlyTracker(monthKey: "2026-12"))
        XCTAssertEqual(router.monthRequest?.monthKey, "2026-12")
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-11"))
    }

    func testDeepLinkKeepsExplicitSideAcrossDifferentMonth() throws {
        let router = makeRouter()
        XCTAssertTrue(router.open(url: try XCTUnwrap(URL(string: "easyjournal://tracker/2026-12"))))
        XCTAssertNil(router.monthRequest)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        try complete(router)
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-12"))
        XCTAssertTrue(router.open(url: try XCTUnwrap(URL(string: "easyjournal://monthly/2027-01"))))
        try complete(router)
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2027-01"))
    }

    func testBlockedFailedAndStaleSideRequestsKeepCurrentPage() throws {
        let router = makeRouter()
        let destination = PageRef.monthlyTracker(monthKey: "2026-10")
        for resolution in [GuardedOpenResolution.blocked, .failed] {
            router.open(destination)
            let request = try XCTUnwrap(router.pageLeaveRequest)
            XCTAssertFalse(router.resolveGuardedOpen(destination, requestToken: request.token, resolution: resolution))
            XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
        }
        router.open(destination)
        let old = try XCTUnwrap(router.pageLeaveRequest)
        let auth = PageLeaveAuthorization.makeForTests(destination: destination, requestToken: old.token)
        router.open(destination)
        XCTAssertFalse(router.resolveGuardedOpen(destination, requestToken: old.token, resolution: .passed(auth)))
        router.endGuardingMonthlyNavigation()
        XCTAssertFalse(router.resolveGuardedOpen(destination, requestToken: old.token, resolution: .passed(auth)))
        XCTAssertEqual(router.current, .monthlyLog(monthKey: "2026-10"))
    }

    func testDelayedCommitTicketIsInvalidAfterNewRequestOrDisappearance() {
        let gate = MoveCommitGate()
        let first = gate.issue()
        XCTAssertTrue(gate.allows(first))
        gate.invalidatePending()
        XCTAssertFalse(gate.allows(first))
        let next = gate.issue()
        XCTAssertFalse(gate.allows(first))
        XCTAssertTrue(gate.allows(next))
        gate.invalidatePending()
        XCTAssertFalse(gate.allows(next))
    }

    func testTrackerLaunchRemainsDirectBeforeGuarding() {
        let router = Router()
        router.open(.monthlyTracker(monthKey: "2026-12"))
        XCTAssertEqual(router.current, .monthlyTracker(monthKey: "2026-12"))
    }
}
