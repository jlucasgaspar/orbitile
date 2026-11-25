import CoreGraphics
import Foundation
import OrbitileCore

var failures = 0
func expect<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    if a == b { print("ok   \(name)") } else { print("FAIL \(name): \(a) != \(b)"); failures += 1 }
}

expect(FanGeometry.hit(CGPoint(x: 0, y: -80), expanded: nil), .family(0), "ring 12h -> family 2")
expect(FanGeometry.hit(CGPoint(x: 80, y: 0), expanded: nil), .family(1), "ring 3h -> family 4")
expect(FanGeometry.hit(CGPoint(x: 0, y: 80), expanded: nil), .family(2), "ring 6h -> family 6")
expect(FanGeometry.hit(CGPoint(x: -80, y: 0), expanded: nil), .family(3), "ring 9h -> family 8")
expect(FanGeometry.hit(CGPoint(x: 0, y: 40), expanded: nil), .none, "center without grid is invalid")
expect(FanGeometry.hit(CGPoint(x: 200, y: 0), expanded: nil), .none, "outside fan is invalid")

let f4 = LayoutFamily.all[1]
let c3 = FanGeometry.cellRect(f4, index: 3)
let p = CGPoint(x: c3.midX, y: c3.midY)
expect(FanGeometry.hit(p, expanded: f4), .cell(3), "cell hit when expanded")
expect(FanGeometry.hit(p, expanded: nil), .none, "no cell hit when collapsed")

var s = FanState()
expect(s.selection == nil, true, "no selection initially")
s.update(.cell(1)); expect(s.selection == nil, true, "cell without family ignored")
s.update(.family(1)); s.update(.cell(2)); expect(s.selection?.cell, 2, "cell selected")
s.update(.none); expect(s.selection == nil, true, "leaving cell clears selection")
s.update(.cell(2)); s.update(.family(2)); expect(s.selection == nil, true, "family switch clears cell")

var d = FanState()
d.update(.family(3)); d.update(.cell(1)); d.beginDrag()
expect(d.isDragging, true, "drag starts on a cell")
d.update(.family(0)); expect(d.familyIndex, 3, "family frozen while dragging")
d.update(.cell(6)); expect(d.span?.first, 1, "span first is anchor")
expect(d.span?.last, 6, "span last is hovered")
d.update(.none); expect(d.span == nil, true, "leaving cells clears span, drag stays")
expect(d.isDragging, true, "still dragging after leaving cells")
d.endDrag(); expect(d.isDragging, false, "drag ends")
var k = FanState(); k.select(family: 2); expect(k.familyIndex, 2, "key selects family")
k.update(.cell(0)); k.select(family: 1); expect(k.cell, nil, "key switch clears cell")

let f8 = LayoutFamily.all[3]
let big = CGRect(x: 0, y: 0, width: 400, height: 200)
expect(FanGeometry.targetRect(f8, from: 1, to: 6, in: big, inset: 0), CGRect(x: 100, y: 0, width: 200, height: 200), "merge 1..6 spans two cols, both rows")
expect(FanGeometry.targetRect(f8, from: 2, to: 0, in: big, inset: 0), CGRect(x: 0, y: 100, width: 300, height: 100), "merge is order independent")
expect(FanGeometry.targetRect(f8, from: 5, to: 5, in: big, inset: 0), FanGeometry.targetRect(f8, cell: 5, in: big, inset: 0), "single cell span equals cell")
expect(abs(Easing.cubicBezier(0.2, 0.8, 0.2, 1, 0.5) - 0.5) > 0.1, true, "easing is non-linear")
expect(Easing.cubicBezier(0.2, 0.8, 0.2, 1, 1), 1, "easing ends at 1")

let area = CGRect(x: 0, y: 0, width: 1440, height: 876)
expect(FanGeometry.targetRect(f4, cell: 0, in: area, inset: 0), CGRect(x: 0, y: 438, width: 720, height: 438), "cell 0 is top-left")
expect(FanGeometry.targetRect(f4, cell: 3, in: area, inset: 0), CGRect(x: 720, y: 0, width: 720, height: 438), "cell 3 is bottom-right")
expect(FanGeometry.clampCenter(CGPoint(x: 5, y: 5), in: CGRect(x: 0, y: 0, width: 1000, height: 800)), CGPoint(x: 119, y: 119), "fan slides to fit")

exit(failures == 0 ? 0 : 1)
