import Foundation

public enum Hardware {
    /// Every Mac that shipped with a Touch Bar, by `hw.model`.
    /// MacBookPro13,1 and 14,1 (2016/2017 13-inch, two ports, function keys) have none.
    public static let touchBarModels: Set<String> = [
        "MacBookPro13,2", "MacBookPro13,3",                     // 2016
        "MacBookPro14,2", "MacBookPro14,3",                     // 2017
        "MacBookPro15,1", "MacBookPro15,2",                     // 2018
        "MacBookPro15,3", "MacBookPro15,4",                     // 2019
        "MacBookPro16,1", "MacBookPro16,4",                     // 2019 16-inch
        "MacBookPro16,2", "MacBookPro16,3",                     // 2020 13-inch Intel
        "MacBookPro17,1",                                       // 2020 13-inch M1
        "Mac14,7",                                              // 2022 13-inch M2
    ]

    public static func hasTouchBar(model: String) -> Bool {
        touchBarModels.contains(model)
    }
}
