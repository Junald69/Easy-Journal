import Foundation

/// タスクの進み具合と、繰越済みかのルール。
///
/// 保存には触らない。記号、タップの次、繰越できるか、だけを返す。
/// 完了（done）かつ繰越済みは、作らない組み合わせ。そのときは nil か false を返す。
/// `fatalError` と強制アンラップは使わない。
enum TaskRules {
    /// 画面に出す記号。
    ///
    /// 完了かつ繰越済み（■>）は、この中に無い。
    enum Symbol: String, Equatable {
        /// □ 未完。
        case open
        /// ◧ 一部。
        case partial
        /// ■ 完了。
        case done
        /// □> 未完で繰越済み。
        case openCarried
        /// ◧> 一部で繰越済み。
        case partialCarried

        /// 画面に出す文字。
        var text: String {
            switch self {
            case .open:
                return "□"
            case .partial:
                return "◧"
            case .done:
                return "■"
            case .openCarried:
                return "□>"
            case .partialCarried:
                return "◧>"
            }
        }
    }

    /// 表のとおりの記号。完了かつ繰越済みは nil。
    static func symbol(progress: TaskProgress, isCarriedForward: Bool) -> Symbol? {
        switch progress {
        case .open:
            if isCarriedForward {
                return .openCarried
            }
            return .open
        case .partial:
            if isCarriedForward {
                return .partialCarried
            }
            return .partial
        case .done:
            if isCarriedForward {
                return nil
            }
            return .done
        }
    }

    /// タップ1回ぶん進める。open → partial → done → open。
    static func nextProgress(_ progress: TaskProgress) -> TaskProgress {
        switch progress {
        case .open:
            return .partial
        case .partial:
            return .done
        case .done:
            return .open
        }
    }

    /// 記号をタップしたあとの進み具合。
    ///
    /// 繰越済みなら、今の進み具合のまま。そうでなければ `nextProgress`。
    static func progressAfterTap(progress: TaskProgress, isCarriedForward: Bool) -> TaskProgress {
        if isCarriedForward {
            return progress
        }
        return nextProgress(progress)
    }

    /// 繰越できるか。未完か一部で、まだ繰越していないときだけ true。
    ///
    /// 完了は繰越できない。すでに繰越済みなら、もう一度はできない。
    static func canCarryForward(progress: TaskProgress, isCarriedForward: Bool) -> Bool {
        switch progress {
        case .open, .partial:
            if isCarriedForward {
                return false
            }
            return true
        case .done:
            return false
        }
    }

    /// 繰越を取り消せるか。
    ///
    /// 繰越済みの未完・一部だけ true。完了かつ繰越済みは作らない組み合わせなので false。
    static func canCancelCarryForward(progress: TaskProgress, isCarriedForward: Bool) -> Bool {
        switch progress {
        case .open, .partial:
            return isCarriedForward
        case .done:
            return false
        }
    }

    /// 進み具合と繰越済みの組み合わせが作ってよいか。
    ///
    /// 完了かつ繰越済みだけ false。
    static func isValidCombination(progress: TaskProgress, isCarriedForward: Bool) -> Bool {
        switch progress {
        case .open, .partial:
            return true
        case .done:
            if isCarriedForward {
                return false
            }
            return true
        }
    }

    /// 記号タップで進み具合を変えてよいか。繰越済みなら false。
    static func isTappable(progress: TaskProgress, isCarriedForward: Bool) -> Bool {
        switch progress {
        case .open, .partial, .done:
            if isCarriedForward {
                return false
            }
            return true
        }
    }
}
