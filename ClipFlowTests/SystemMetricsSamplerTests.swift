import XCTest
@testable import ClipFlow

final class SystemMetricsSamplerTests: XCTestCase {
    func testActivityMonitorDestinationsMatchNativeMetricViews() {
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .cpu), .cpu)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .gpu), .gpuHistory)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .memory), .memory)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .temperature), .cpu)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .storage), .disk)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .network), .network)
        XCTAssertEqual(ActivityMonitorDestination.destination(for: .power), .energy)
    }

    func testMenuBarOverflowMovesItemsOutsideTheRightNotchArea() {
        let rightArea = NSRect(x: 900, y: 950, width: 500, height: 38)

        let fittingItems: [MenuBarMetric: MenuBarItemGeometry] = [
            .cpu: MenuBarItemGeometry(
                frame: NSRect(x: 980, y: 952, width: 70, height: 30),
                isWindowVisible: true
            )
        ]
        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(items: fittingItems, rightArea: rightArea),
            []
        )

        let partiallyOverflowingItems = fittingItems.merging([
            .temperature: MenuBarItemGeometry(
                frame: NSRect(x: 870, y: 952, width: 70, height: 30),
                isWindowVisible: true
            )
        ]) { _, updated in updated }
        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(items: partiallyOverflowingItems, rightArea: rightArea),
            [.temperature]
        )
    }

    func testMenuBarOverflowDetectsOneHiddenItemWithoutReactingWhenAllAreHidden() {
        let rightArea = NSRect(x: 900, y: 950, width: 500, height: 38)
        let frame = NSRect(x: 980, y: 952, width: 70, height: 30)

        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(
                items: [
                    .cpu: MenuBarItemGeometry(frame: frame, isWindowVisible: true),
                    .gpu: MenuBarItemGeometry(frame: frame.offsetBy(dx: 80, dy: 0), isWindowVisible: false)
                ],
                rightArea: rightArea
            ),
            [.gpu]
        )
        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(
                items: [.cpu: MenuBarItemGeometry(frame: frame, isWindowVisible: false)],
                rightArea: rightArea
            ),
            []
        )
    }

    func testMenuBarOverflowMovesOnlyOneLowPriorityItemPerMeasurement() {
        let rightArea = NSRect(x: 900, y: 950, width: 500, height: 38)
        let outsideFrame = NSRect(x: 820, y: 952, width: 70, height: 30)
        let items: [MenuBarMetric: MenuBarItemGeometry] = [
            .cpu: MenuBarItemGeometry(frame: outsideFrame, isWindowVisible: false),
            .gpu: MenuBarItemGeometry(frame: outsideFrame, isWindowVisible: false),
            .memory: MenuBarItemGeometry(frame: outsideFrame, isWindowVisible: false),
            .temperature: MenuBarItemGeometry(frame: outsideFrame, isWindowVisible: false)
        ]

        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(items: items, rightArea: rightArea),
            [.temperature]
        )
        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(
                items: items.filter { $0.key != .temperature },
                rightArea: rightArea
            ),
            [.memory]
        )
    }

    func testMenuBarOverflowAlwaysKeepsOneMetricOnTheRight() {
        let rightArea = NSRect(x: 900, y: 950, width: 500, height: 38)
        let outsideItem = MenuBarItemGeometry(
            frame: NSRect(x: 820, y: 952, width: 70, height: 30),
            isWindowVisible: false
        )

        XCTAssertEqual(
            MenuBarOverflowLayout.metricsToMoveLeft(
                items: [.cpu: outsideItem],
                rightArea: rightArea
            ),
            []
        )
    }

    func testCPUSampleProducesNormalizedFractions() throws {
        let sampler = CPUMetricsSampler()
        _ = try XCTUnwrap(sampler.sample())
        usleep(50_000)

        let sample = try XCTUnwrap(sampler.sample())
        XCTAssertTrue((0 ... 1).contains(sample.user))
        XCTAssertTrue((0 ... 1).contains(sample.system))
        XCTAssertTrue((0 ... 1).contains(sample.idle))
        XCTAssertEqual(sample.user + sample.system + sample.idle, 1, accuracy: 0.001)
    }

    func testMemorySampleStaysWithinPhysicalMemory() throws {
        let sample = try XCTUnwrap(MemoryMetricsSampler().sample())

        XCTAssertGreaterThan(sample.totalBytes, 0)
        XCTAssertLessThanOrEqual(sample.usedBytes, sample.totalBytes)
        XCTAssertTrue((0 ... 1).contains(sample.usedFraction))
    }

    func testGPUReadsIOAcceleratorStatisticsWhenAvailable() throws {
        let sampler = GPUMetricsSampler()
        let sample = try XCTUnwrap(sampler.sample())

        XCTAssertFalse(sampler.deviceName.isEmpty)
        XCTAssertGreaterThan(sampler.coreCount ?? 0, 0)
        XCTAssertTrue((0 ... 1).contains(sample.device))
    }

    func testThermalSampleRejectsInvalidSensorValues() throws {
        let sample = ThermalMetricsSampler().sample()
        let temperature = try XCTUnwrap(sample.peakTemperature)

        XCTAssertTrue((5 ... 125).contains(temperature))
        XCTAssertGreaterThan(sample.sensorCount, 0)
        XCTAssertEqual(sample.sensorCount, Set(sample.sensors.map(\.id)).count)
        XCTAssertEqual(temperature, try XCTUnwrap(sample.sensors.map(\.temperature).max()), accuracy: 0.001)
        XCTAssertTrue(sample.sensors.allSatisfy { $0.ordinal > 0 })
        for group in ThermalSensorGroup.allCases {
            let ordinals = sample.sensors.filter { $0.group == group }.map(\.ordinal)
            if !ordinals.isEmpty {
                XCTAssertEqual(ordinals, Array(1 ... ordinals.count))
            }
        }
    }

    func testStorageSampleReportsCapacityAndNormalizedUsage() {
        let sample = StorageMetricsSampler().sample()

        XCTAssertGreaterThan(sample.totalBytes, 0)
        XCTAssertLessThanOrEqual(sample.availableBytes, sample.totalBytes)
        XCTAssertTrue((0 ... 1).contains(sample.usedFraction))
        XCTAssertFalse(sample.volumeName.isEmpty)
    }

    func testNetworkSampleNeverProducesNegativeRates() {
        let sampler = NetworkMetricsSampler()
        _ = sampler.sample()
        usleep(50_000)
        let sample = sampler.sample()

        XCTAssertGreaterThanOrEqual(sample.downloadBytesPerSecond, 0)
        XCTAssertGreaterThanOrEqual(sample.uploadBytesPerSecond, 0)
    }

    func testPowerSampleUsesValidRangesWhenBatteryIsAvailable() {
        let sample = PowerMetricsSampler().sample()

        if let level = sample.batteryLevel {
            XCTAssertTrue((0 ... 1).contains(level))
        }
        if let health = sample.healthPercent {
            XCTAssertTrue((0 ... 1).contains(health))
        }
        if let watts = sample.powerWatts {
            XCTAssertGreaterThanOrEqual(watts, 0)
        }
    }

    @MainActor
    func testMenuBarMetricStylesPersist() throws {
        let suiteName = "SystemMetricsSamplerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: defaults)
        settings.setMenuBarStyle(.textAndGraph, for: .network)
        settings.metricsPopoverMode = .detailed
        settings.useNotchLeftOverflow = false

        let restored = AppSettings(userDefaults: defaults)
        XCTAssertEqual(restored.menuBarStyle(for: .network), .textAndGraph)
        XCTAssertEqual(restored.menuBarStyle(for: .cpu), .text)
        XCTAssertEqual(restored.metricsPopoverMode, .detailed)
        XCTAssertFalse(restored.useNotchLeftOverflow)
    }
}
