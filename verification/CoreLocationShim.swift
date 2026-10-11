import Foundation

public struct CLLocationCoordinate2D: Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public func CLLocationCoordinate2DIsValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
    coordinate.latitude.isFinite
        && coordinate.longitude.isFinite
        && (-90...90).contains(coordinate.latitude)
        && (-180...180).contains(coordinate.longitude)
}

public struct CLLocation: Sendable {
    private let coordinate: CLLocationCoordinate2D

    public init(latitude: Double, longitude: Double) {
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public func distance(from location: CLLocation) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let latitudeDelta = (location.coordinate.latitude - coordinate.latitude).degreesToRadians
        let longitudeDelta = (location.coordinate.longitude - coordinate.longitude).degreesToRadians
        let startLatitude = coordinate.latitude.degreesToRadians
        let endLatitude = location.coordinate.latitude.degreesToRadians
        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(startLatitude) * cos(endLatitude) * pow(sin(longitudeDelta / 2), 2)
        return earthRadiusMeters * 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
