import CoreLocation
import Foundation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()

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
        clManager.requestWhenInUseAuthorization()
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
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self, let placemark = placemarks?.first else { return }
            Task { @MainActor in
                self.cityName = placemark.locality ?? placemark.administrativeArea ?? ""
                self.districtName = placemark.subLocality ?? ""
                self.streetName = placemark.thoroughfare ?? ""

                var parts: [String] = []
                if !self.cityName.isEmpty { parts.append(self.cityName) }
                if !self.districtName.isEmpty { parts.append(self.districtName) }
                if !self.streetName.isEmpty { parts.append(self.streetName) }
                self.locationString = parts.isEmpty ? "未知位置" : parts.joined(separator: " ")
            }
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
