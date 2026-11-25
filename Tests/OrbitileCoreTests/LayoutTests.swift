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

    @Test func targetRectTopRowIsAtTop() {
        let area = CGRect(x: 0, y: 0, width: 1440, height: 876)
        let top = FanGeometry.targetRect(LayoutFamily.all[1], cell: 0, in: area, inset: 0)
        #expect(top == CGRect(x: 0, y: 438, width: 720, height: 438))
        let bottom = FanGeometry.targetRect(LayoutFamily.all[1], cell: 3, in: area, inset: 0)
        #expect(bottom == CGRect(x: 720, y: 0, width: 720, height: 438))
    }

    @Test func clampKeepsFanOnScreen() {
        let c = FanGeometry.clampCenter(CGPoint(x: 5, y: 5), in: CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(c == CGPoint(x: 119, y: 119))
    }
}

@Suite struct StateTests {
    @Test func hoverFlow() {
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

    @Test func startsOnGivenFamily() {
        #expect(FanState(family: 3).familyIndex == 3)
        #expect(FanState(family: 9).familyIndex == nil)
        #expect(FanState().familyIndex == nil)
    }

    @Test func keyboardSelectsFamilyAndClearsCell() {
        var s = FanState(family: 3)
        s.update(.cell(2))
        s.select(family: 1)
        #expect(s.familyIndex == 1)
        #expect(s.cell == nil)
        s.select(family: 7)
        #expect(s.familyIndex == 1)
    }

    @Test func dragFreezesFamilyAndBuildsSpan() {
        var s = FanState(family: 3)
        s.update(.cell(1))
        s.beginDrag()
        #expect(s.isDragging)
        s.update(.family(0))
        #expect(s.familyIndex == 3)
        s.select(family: 0)
        #expect(s.familyIndex == 3)
        s.update(.cell(6))
        #expect(s.span?.first == 1)
        #expect(s.span?.last == 6)
    }

    @Test func leavingCellsClearsSpanButKeepsDrag() {
        var s = FanState(family: 3)
        s.update(.cell(1))
        s.beginDrag()
        s.update(.none)
        #expect(s.span == nil)
        #expect(s.isDragging)
        s.endDrag()
        #expect(!s.isDragging)
    }

    @Test func beginDragWithoutCellDoesNothing() {
        var s = FanState(family: 3)
        s.beginDrag()
        #expect(!s.isDragging)
    }

    @Test func singleCellSpanUsesHoveredCell() {
        var s = FanState(family: 1)
        s.update(.cell(2))
        #expect(s.span?.first == 2)
        #expect(s.span?.last == 2)
    }
}

@Suite struct MergeTests {
    private let area = CGRect(x: 0, y: 0, width: 400, height: 200)
    private let eight = LayoutFamily.all[3]

    @Test func spanCoversBoundingBox() {
        let r = FanGeometry.targetRect(eight, from: 1, to: 6, in: area, inset: 0)
        #expect(r == CGRect(x: 100, y: 0, width: 200, height: 200))
    }

    @Test func spanIsOrderIndependent() {
        let r = FanGeometry.targetRect(eight, from: 2, to: 0, in: area, inset: 0)
        #expect(r == CGRect(x: 0, y: 100, width: 300, height: 100))
        #expect(r == FanGeometry.targetRect(eight, from: 0, to: 2, in: area, inset: 0))
    }

    @Test func singleCellSpanEqualsCell() {
        #expect(
            FanGeometry.targetRect(eight, from: 5, to: 5, in: area, inset: 0)
                == FanGeometry.targetRect(eight, cell: 5, in: area, inset: 0))
    }

    @Test func miniScreenSpanIsUnionOfCells() {
        let union = FanGeometry.cellRect(eight, from: 1, to: 6)
        #expect(union == FanGeometry.cellRect(eight, index: 1).union(FanGeometry.cellRect(eight, index: 6)))
    }
}

@Suite struct EasingTests {
    @Test func endpointsAreFixed() {
        #expect(Easing.cubicBezier(0.2, 0.8, 0.2, 1, 0) == 0)
        #expect(Easing.cubicBezier(0.2, 0.8, 0.2, 1, 1) == 1)
    }

    @Test func curveIsFrontLoaded() {
        let mid = Easing.cubicBezier(0.2, 0.8, 0.2, 1, 0.5)
        #expect(mid > 0.8 && mid < 1)
    }

    @Test func linearCurveIsIdentity() {
        let v = Easing.cubicBezier(0, 0, 1, 1, 0.37)
        #expect(abs(v - 0.37) < 0.001)
    }
}
