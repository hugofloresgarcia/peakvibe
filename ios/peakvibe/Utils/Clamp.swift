//
//  Clamp.swift
//  peakvibe
//
//  https://stackoverflow.com/questions/36110620/standard-way-to-clamp-a-number-between-two-values-in-swift
//

import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Int {
    func clamped(to limits: Range<Self>) -> Self {
        return Swift.min(Swift.max(self, limits.lowerBound), limits.upperBound - 1)
    }
}
