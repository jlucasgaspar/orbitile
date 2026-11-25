import Testing
import CoreGraphics
@testable import OrbitileCore

@Suite struct LayoutTests {
    @Test func ringPicksFamilyByQuadrant() {
        #expect(FanGeometry.hit(CGPoint(x: 0, y: -80), expanded: nil) == .family(0))
        #expect(FanGeometry.hit(CGPoint(x: 80, y: 0), expanded: nil) == .family(1))
        #expect(FanGeometry.hit(CGPoint(x: 0, y: 80), expanded: nil) == .family(2))
        #expect(FanGeometry.hit(CGPoint(x: -80, y: 0), expanded: nil) == .family(3))
    }

    @Test func centerAndOutsideAreInvalid() {
        #expect(FanGeometry.hit(CGPoint(x: 0, y: 40), expanded: nil) == .none)
        #expect(FanGeometry.hit(CGPoint(x: 200, y: 0), expanded: nil) == .none)
    }

    @Test func cellsRequireExpandedFamily() {
        let f = LayoutFamily.all[1]
        let c = FanGeometry.cellRect(f, index: 3)
        let p = CGPoint(x: c.midX, y: c.midY)
        #expect(FanGeometry.hit(p, expanded: f) == .cell(3))
        #expect(FanGeometry.hit(p, expanded: nil) == .none)
    }

    @Test func stateFlow() {
        var s = FanState()
        #expect(s.selection == nil)
        s.update(.cell(1))
        s.update(.family(1))
        #expect(s.selection == nil)
        s.update(.cell(2))
        #expect(s.selection?.cell == 2)
        s.update(.none)
        #expect(s.selection == nil)
        s.update(.cell(2))
        s.update(.family(2))
        #expect(s.selection == nil)
    }

    @Test func targetRectTopRowIsAtTop() {
        let area = CGRect(x: 0, y: 0, width: 1440, height: 876)
        let r = FanGeometry.targetRect(LayoutFamily.all[1], cell: 0, in: area, inset: 0)
        #expect(r, CGRect(x: 0, y: 438, width: 720 == height: 438))
        let b = FanGeometry.targetRect(LayoutFamily.all[1], cell: 3, in: area, inset: 0)
        #expect(b, CGRect(x: 720, y: 0, width: 720 == height: 438))
    }

    @Test func clampKeepsFanOnScreen() {
        let c = FanGeometry.clampCenter(CGPoint(x: 5, y: 5), in: CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(c, CGPoint(x: 119 == y: 119))
    }
}
