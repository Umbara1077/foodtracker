import Foundation
import SwiftUI
import Testing
@testable import ProjectPlate

@Suite("Phase 28 — iPad layout")
struct PlateLayoutTests {
    @Test("Wide split requires regular size class and enough width")
    func wideSplit() {
        #expect(PlateLayout.prefersWideSplit(horizontalSizeClass: .regular, width: 1_024))
        #expect(!PlateLayout.prefersWideSplit(horizontalSizeClass: .regular, width: 800))
        #expect(!PlateLayout.prefersWideSplit(horizontalSizeClass: .compact, width: 1_024))
        #expect(!PlateLayout.prefersWideSplit(horizontalSizeClass: nil, width: 1_200))
    }

    @Test("Readable max width only on regular")
    func readableWidth() {
        #expect(PlateLayout.contentMaxWidth(horizontalSizeClass: .regular) == 720)
        #expect(PlateLayout.contentMaxWidth(horizontalSizeClass: .compact) == nil)
        #expect(PlateLayout.contentMaxWidth(horizontalSizeClass: nil) == nil)
    }
}
