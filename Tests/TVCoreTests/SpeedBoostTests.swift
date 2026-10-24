import Testing
@testable import TVCore

@Test func holdingThePictureStepsThroughSpeedsSideways() {
    var boost = SpeedBoost(rate: 2)
    #expect(boost.rate == 2 && !boost.locked)
    boost.moved(x: 49, y: 20)
    #expect(boost.rate == 2)
    boost.moved(x: 50, y: 0)
    #expect(boost.rate == 2.5)
    boost.moved(x: 100, y: 0)
    #expect(boost.rate == 3)
    boost.moved(x: 500, y: 0)
    #expect(boost.rate == 4)
    boost.moved(x: -60, y: 0)
    #expect(boost.rate == 1.5)
    boost.moved(x: -100, y: 0)
    #expect(boost.rate == 1)
    boost.moved(x: -500, y: 0)
    #expect(boost.rate == 0.5)
    boost.moved(x: .nan, y: .infinity)
    #expect(boost.rate == 0.5 && !boost.locked)
}

@Test func slidingDownKeepsTheSpeedAfterLettingGo() {
    var boost = SpeedBoost(rate: 3)
    boost.moved(x: -50, y: 79)
    #expect(!boost.locked)
    boost.moved(x: -50, y: 80)
    #expect(boost.locked && boost.rate == 2.5)
    // Moving back up doesn't let it go again; tapping its label does.
    boost.moved(x: 0, y: 0)
    #expect(boost.locked && boost.rate == 3)
}

@Test func holdSpeedStartsAtTheNearestRate() {
    #expect(SpeedBoost(rate: 3).rate == 3)
    #expect(SpeedBoost(rate: 4).rate == 4)
    #expect(SpeedBoost(rate: 7).rate == 4)
    #expect(SpeedBoost(rate: 0.5).rate == 0.5)
    #expect(SpeedBoost(rate: 0.1).rate == 0.5)
    #expect(SpeedBoost(rate: .nan).rate == SpeedBoost.standard)
}

@Test func holdsStartSlowerOrFasterButNotAtNormalSpeed() {
    #expect(SpeedBoost.startRates == [0.5, 1.5, 2, 2.5, 3, 4])
    #expect(SpeedBoost.startRates.contains(SpeedBoost.standard))
}
