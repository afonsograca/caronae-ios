import Foundation

class RideService: NSObject {
    static let instance = RideService()
    let api = CaronaeAPIHTTPSessionManager.instance
    
    private override init() {
        // This prevents others from using the default '()' initializer for this class.
    }
    
    func getAllRides(success: @escaping (_ rides: [Ride]) -> Void, error: @escaping (_ error: Error?) -> Void) {
        api.get("/ride/all", parameters: nil, success: { task, responseObject in
            guard let ridesJson = responseObject as? [[String: Any]] else {
                print("Error parsing rides")
                error(nil)
                return
            }
            
            // Deserialize response
            var rides = ridesJson.flatMap { Ride(JSON: $0) }
            
            // Skip rides in the past
            rides = rides.filter { $0.date.isInTheFuture() }
            
            // Sort rides by date/time
            rides = rides.sorted { $0.date < $1.date }
            
            success(rides)
            
        }, failure: { _, err in
            print("Failed to load all rides: \(err.localizedDescription)")
            error(err)
        })
    }
    
    func removeRideFromMyRides (ride: Ride) {
        // Find and delete ride from persistent store
        guard let userRidesArchive = UserDefaults.standard.object(forKey: "userCreatedRides") as? [Dictionary<String, Any>] else {
            NSLog("Error: userCreatedRides was not found in UserDefaults")
            return
        }
        
        var newRides = userRidesArchive
        for (index, r) in newRides.enumerated() {
            if r["rideId"] as? Int == ride.id || r["id"] as? Int == ride.id {
                NSLog("Ride with id \(ride.id) deleted from user's rides")
                newRides.remove(at: index)
                UserDefaults.standard.set(newRides, forKey: "userCreatedRides")
                return
            }
        }
        NSLog("Error: ride to be deleted was not found in user's rides")
    }
    
    func getOfferedRides(success: @escaping (_ rides: [Ride]) -> Void, error: @escaping (_ error: Error?) -> Void) {
        guard let userID = UserService.instance.user?.id else {
            NSLog("Error: No userID registered")
            return
        }
        
        api.get("/user/\(userID)/offeredRides", parameters: nil, success: { task, responseObject in
            do {
                guard let jsonResponse = responseObject as? [String: Any],
                    let ridesJson = jsonResponse["rides"] as? [[String: Any]] else {
                    NSLog("Error: rides was not found in responseObject")
                    error(nil)
                    return
                }
                
                // Deserialize response
                let rides = ridesJson.flatMap { Ride(JSON: $0) }
                
                // TODO: Persist offered rides
                
                success(rides)
            }
        }, failure: { _, err in
            NSLog("Error: Failed to get offered rides: \(err.localizedDescription)")
            error(err)
        })
    }

    func getActiveRides(success: @escaping (_ rides: [Ride]) -> Void, error: @escaping (_ error: Error?) -> Void) {
        api.get("/ride/getMyActiveRides", parameters: nil, success: { task, responseObject in
            do {
                guard let ridesJson = responseObject as? [[String: Any]] else {
                    NSLog("Error: Invalid response from the API")
                    error(nil)
                    return
                }
                
                let rides = ridesJson.flatMap { Ride(JSON: $0) }.sorted { $0.date < $1.date }
                success(rides)
            }
        }, failure: { _, err in
            NSLog("Error: Failed to get active rides: \(err.localizedDescription)")
            error(err)
        })

    }
    
//    func getRidesHistory(success: @escaping (_ rides: [Ride]) -> Void, error: @escaping (_ error: Error?) -> Void) {
//        
//    }
//    
//    // etc
}
