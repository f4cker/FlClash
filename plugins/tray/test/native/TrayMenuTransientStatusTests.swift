import AppKit

@main
struct TrayMenuTransientStatusTests {
    static let pending = "正在切换到全局模式中"
    static let failure = "切换失败：fixture reason"

    static func status(_ label: String, id: Int = 1027, key: String = "outbound-mode") -> [String: Any] {
        ["type": "action", "id": id, "transientStatusKey": key,
         "label": label, "accessibilityLabel": label, "enabled": false]
    }

    static func action(_ label: String, id: Int, enabled: Bool = true) -> [String: Any] {
        ["type": "action", "id": id, "label": label, "enabled": enabled]
    }

    static func modes(selected: String, enabled: Bool) -> [[String: Any]] {
        ["Rule", "Global", "Direct"].enumerated().map { index, label in
            ["type": "checkbox", "id": 1024 + index, "label": label,
             "segmentGroup": "outbound-mode", "checked": label == selected, "enabled": enabled]
        }
    }

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() {
        testStatusIdentity()
        testRetainedSuccessAndFailure()
        testUnrelatedRowsAndDisabledActions()
        Swift.print("PASS: transient status identity, retained native/view/AX state, IDs, generation and disabled actions")
    }

    static func testStatusIdentity() {
        let old = status(pending)
        let ordinary = action(pending, id: 1027, enabled: false)
        check(TrayMenuTransientStatus.retained(ordinary, current: [ordinary], desired: []) == nil,
              "ordinary disabled actions are not transient")
        check(TrayMenuTopology.sharedIndex(ordinary, current: [ordinary], desired: [old]) == nil,
              "ordinary matching cannot adopt a status with the same label")
        for desired in [[], [status(failure, key: "other")], [status(failure), status("duplicate")], [ordinary]] {
            let cleared = TrayMenuTransientStatus.retained(old, current: [old], desired: desired)!
            check(cleared["label"] as? String == "", "absent or ambiguous status clears")
            check(cleared["accessibilityLabel"] as? String == "", "stale AX label clears")
            check(cleared["enabled"] as? Bool == false, "status never becomes actionable")
        }
        let duplicated = TrayMenuTransientStatus.retained(old, current: [old, old], desired: [status(failure)])!
        check(duplicated["label"] as? String == "", "ambiguous retained identity clears")
        var decorated = old
        decorated["detail"] = pending
        decorated["badge"] = ["label": pending]
        decorated["icon"] = ["monogram": pending]
        let cleared = TrayMenuTransientStatus.retained(decorated, current: [decorated], desired: [])!
        check(cleared["detail"] == nil && cleared["badge"] == nil && cleared["icon"] == nil,
              "retirement removes all stale presentation fragments")
    }

    static func testRetainedSuccessAndFailure() {
        var selections: [(Int, Int)] = []
        let initial = modes(selected: "Rule", enabled: false) + [status(pending), action("Exit", id: 1028)]
        let menu = TrayMenu(items: initial, generation: 7, onSelect: { selections.append(($0, $1)) })
        menu.menuNeedsUpdate(menu)
        let retainedItems = menu.items
        let views = retainedItems.map { $0.view! }
        let row = retainedItems[1]
        let view = views[1] as! TrayMenuItemView
        let frame = view.frame
        check(row.title == pending && view.accessibilityLabel() == pending, "pending is initially visible and accessible")

        let success = modes(selected: "Global", enabled: true) + [action("Exit", id: 1027)]
        check(!menu.reconcile(items: success, generation: 8), "removed status retains the tracking topology")
        check(row.title.isEmpty && row.toolTip == "", "success clears native title and tooltip")
        check(view.accessibilityLabel() == "" && view.toolTip == "", "success clears drawn view accessibility and tooltip")
        check(!row.isEnabled && !view.accessibilityPerformPress(), "retired status cannot activate")
        check(view.frame == frame, "tracking geometry is unchanged")
        check(menu.generation == 7 && row.tag == 1027 && menu.items[2].tag == 1028, "retained generation and tags are unchanged")
        let segments = views[0] as! TrayMenuSegmentsView
        let children = segments.accessibilityChildren() as! [NSView]
        check(children[1].accessibilityValue() as? Int == 1, "confirmed Global selection reaches AX")

        let shiftedModes = modes(selected: "Rule", enabled: true).map { entry -> [String: Any] in
            var shifted = entry
            shifted["id"] = (entry["id"] as! Int) + 200
            return shifted
        }
        let failed = shiftedModes + [status(failure, id: 9000), action("Exit", id: 9001)]
        check(!menu.reconcile(items: failed, generation: 9), "error replaces the cleared semantic slot")
        check(row.title == failure && row.toolTip == failure, "failure replaces native pending text")
        check(view.accessibilityLabel() == failure && view.toolTip == failure, "failure replaces accessible pending text")
        check(!row.isEnabled && row.tag == 1027 && menu.generation == 7, "error remains inert in original generation")
        check(menu.items.count == retainedItems.count, "no tracking items are added or removed")
        for index in retainedItems.indices {
            check(menu.items[index] === retainedItems[index] && menu.items[index].view === views[index],
                  "tracking item and view identities are preserved")
        }
        check(selections.isEmpty, "status updates never dispatch callbacks")
        check(children[2].accessibilityPerformPress(), "pending mode segments can re-enable")
        check(selections.count == 1 && selections[0].0 == 1026 && selections[0].1 == 7,
              "segmented selection dispatches the retained option ID and generation")

        let pendingMenu = TrayMenu(items: [status(pending)], generation: 10, onSelect: { _, _ in preconditionFailure() })
        pendingMenu.menuNeedsUpdate(pendingMenu)
        let pendingView = pendingMenu.items[0].view!
        check(!pendingMenu.reconcile(items: [status(failure)], generation: 11), "pending to failure is a retained update")
        check(pendingMenu.items[0].title == failure && pendingView.accessibilityLabel() == failure,
              "direct pending to failure replaces visible and AX text")
    }

    static func testUnrelatedRowsAndDisabledActions() {
        let initial = [status(pending), action("Disabled", id: 1028, enabled: false), action("Old", id: 1029)]
        let menu = TrayMenu(items: initial, generation: 20, onSelect: { _, _ in preconditionFailure() })
        menu.menuNeedsUpdate(menu)
        let desired = [action("Unrelated", id: 1027), action("Disabled", id: 1028)]
        check(!menu.reconcile(items: desired, generation: 21), "structural change is retained")
        check(menu.items[0].title == "", "same index and id never turn a status into an unrelated action")
        check(!menu.items[1].isEnabled, "initially disabled actions cannot be re-enabled")
        check(menu.items[2].title == "Old" && !menu.items[2].isEnabled, "ordinary unmatched row behavior is unchanged")
    }
}
