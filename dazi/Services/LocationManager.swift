import CoreLocation
import Foundation
import MapKit

struct DeviceLocationSnapshot {
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let capturedAt: Date
}

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?

    var latitude: Double = 0
    var longitude: Double = 0
    var accuracyMeters: Double = 0
    var capturedAt: Date?
    var isLaunchCityEligible: Bool?
    var cityName: String = ""
    var districtName: String = ""
    var streetName: String = ""
    var locationString: String = "位置获取中..."
    var isAuthorized: Bool = false
    var hasLocation: Bool = false

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        switch clManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            clManager.requestLocation()
        case .notDetermined:
            clManager.requestWhenInUseAuthorization()
        default:
            isAuthorized = false
            locationString = "位置权限未授予"
        }
    }

    func refreshLocation() {
        if clManager.authorizationStatus == .authorizedWhenInUse ||
            clManager.authorizationStatus == .authorizedAlways {
            clManager.requestLocation()
        }
    }

    /// Formatted location for prompts and event creation
    var promptLocationDescription: String {
        if !hasLocation { return "位置未知" }
        var parts: [String] = []
        if !cityName.isEmpty { parts.append(cityName) }
        if !districtName.isEmpty { parts.append(districtName) }
        if !streetName.isEmpty { parts.append(streetName) }
        return parts.isEmpty ? "位置未知" : parts.joined(separator: " ")
    }

    var signupLocationSnapshot: DeviceLocationSnapshot? {
        guard hasLocation,
              let capturedAt,
              accuracyMeters > 0,
              accuracyMeters <= 1000 else {
            return nil
        }
        let age = Date().timeIntervalSince(capturedAt)
        guard age >= -60, age <= 5 * 60 else { return nil }
        return DeviceLocationSnapshot(
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracyMeters,
            capturedAt: capturedAt
        )
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let accuracy = location.horizontalAccuracy
        let timestamp = location.timestamp

        Task { @MainActor in
            self.latitude = lat
            self.longitude = lng
            self.accuracyMeters = accuracy
            self.capturedAt = timestamp
            self.hasLocation = true
            self.reverseGeocode(location: location)
            self.uploadInvitationEligibility(
                latitude: lat,
                longitude: lng,
                accuracyMeters: accuracy,
                capturedAt: timestamp
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error.localizedDescription)")
            self.locationString = "位置获取失败"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.isAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            if self.isAuthorized {
                manager.requestLocation()
            } else if status == .notDetermined {
                // Will wait for user response
            } else {
                self.locationString = "位置权限未授予"
            }
        }
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocode(location: CLLocation) {
        reverseGeocodingRequest?.cancel()
        guard let request = MKReverseGeocodingRequest(location: location) else { return }
        request.preferredLocale = Locale(identifier: "zh_CN")
        reverseGeocodingRequest = request

        request.getMapItems { [weak self, weak request] mapItems, _ in
            guard let self, let request, self.reverseGeocodingRequest === request else { return }
            self.reverseGeocodingRequest = nil

            guard let mapItem = mapItems?.first else {
                self.locationString = "未知位置"
                return
            }

            let city = mapItem.addressRepresentations?.cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let shortAddress = mapItem.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.cityName = city
            self.districtName = ""
            self.streetName = shortAddress == city ? "" : shortAddress

            let parts = [self.cityName, self.streetName].filter { !$0.isEmpty }
            self.locationString = parts.isEmpty ? "未知位置" : parts.joined(separator: " ")
        }
    }

    private func uploadInvitationEligibility(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        capturedAt: Date
    ) {
        guard APIClient.shared.isLoggedIn, accuracyMeters > 0, accuracyMeters <= 1000 else {
            return
        }
        Task {
            do {
                let result = try await APIClient.shared.verifyLaunchCityLocation(
                    latitude: latitude,
                    longitude: longitude,
                    accuracyMeters: accuracyMeters,
                    capturedAt: capturedAt
                )
                await MainActor.run {
                    self.isLaunchCityEligible = result.isLaunchCity
                }
            } catch {
                print("[Invitation] Location eligibility upload failed: \(error.localizedDescription)")
            }
        }
    }
}
