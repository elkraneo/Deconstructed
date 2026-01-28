import Testing
@testable import RCPPackage

@Test func example() async throws {
	#expect(RCPPackage.createInitialBundle().fileWrappers != nil)
}
