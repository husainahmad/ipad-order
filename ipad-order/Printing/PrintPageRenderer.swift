import UIKit

final class MultiLanguageFooterPrintRenderer: UIPrintPageRenderer {

    struct LanguageFont {
        let code: String
        let fontName: String
        let fontSize: CGFloat
    }

    private let footerTexts: [String: String]
    private let languageFonts: [LanguageFont]
    private let customFooterHeight: CGFloat = 60

    init(footerTexts: [String: String], languageFonts: [LanguageFont] = MultiLanguageFooterPrintRenderer.defaultLanguageFonts) {
        self.footerTexts = footerTexts
        self.languageFonts = languageFonts
        super.init()
        // UIKit's footerHeight is the distance from bottom of contentRect
        self.footerHeight = customFooterHeight
        self.headerHeight = 0
    }

    static let defaultLanguageFonts: [LanguageFont] = [
        LanguageFont(code: "en", fontName: "HelveticaNeue", fontSize: 10),
        LanguageFont(code: "id", fontName: "HelveticaNeue", fontSize: 10),
        LanguageFont(code: "ar", fontName: "GeezaPro", fontSize: 10),
        LanguageFont(code: "zh-Hans", fontName: "PingFangSC-Regular", fontSize: 10),
        LanguageFont(code: "ja", fontName: "HiraginoSans-W3", fontSize: 10),
        LanguageFont(code: "ko", fontName: "AppleSDGothicNeo-Regular", fontSize: 10),
        LanguageFont(code: "th", fontName: "Thonburi", fontSize: 10),
        LanguageFont(code: "vi", fontName: "HelveticaNeue", fontSize: 10),
        LanguageFont(code: "ms", fontName: "HelveticaNeue", fontSize: 10),
    ]

    override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 2

        var currentY = footerRect.minY + 4
        let availableWidth = footerRect.width - 20

        for langFont in languageFonts {
            guard let text = footerTexts[langFont.code], !text.isEmpty else { continue }
            let font = UIFont(name: langFont.fontName, size: langFont.fontSize) ?? UIFont.systemFont(ofSize: langFont.fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textRect = attributedString.boundingRect(
                with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            let drawRect = CGRect(
                x: footerRect.minX + 10,
                y: currentY,
                width: availableWidth,
                height: ceil(textRect.height)
            )
            attributedString.draw(in: drawRect)
            currentY = drawRect.maxY + 2
        }
        context?.restoreGState()
    }

    override func drawPage(at pageIndex: Int, in printableRect: CGRect) {
        super.drawPage(at: pageIndex, in: printableRect)
    }
}

final class PrintManager {

    static let shared = PrintManager()
    private init() {}

    func printWithMultiLanguageFooter(
        content: NSAttributedString,
        footerTexts: [String: String],
        languageFonts: [MultiLanguageFooterPrintRenderer.LanguageFont] = MultiLanguageFooterPrintRenderer.defaultLanguageFonts,
        jobName: String = "Receipt",
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            completion(false, NSError(domain: "Print", code: -1, userInfo: [NSLocalizedDescriptionKey: "Printing not available"]))
            return
        }
        let printController = UIPrintInteractionController.shared
        let renderer = MultiLanguageFooterPrintRenderer(footerTexts: footerTexts, languageFonts: languageFonts)
        let printFormatter = content.getPrintFormatter()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = jobName
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printPageRenderer = renderer
        printController.present(from: viewController.view.frame, in: viewController.view, animated: true) { _, completed, error in
            completion(completed, error)
        }
    }

    func printWithMultiLanguageFooter(
        htmlContent: String,
        footerTexts: [String: String],
        languageFonts: [MultiLanguageFooterPrintRenderer.LanguageFont] = MultiLanguageFooterPrintRenderer.defaultLanguageFonts,
        jobName: String = "Receipt",
        from viewController: UIViewController,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            completion(false, NSError(domain: "Print", code: -1, userInfo: [NSLocalizedDescriptionKey: "Printing not available"]))
            return
        }
        let printController = UIPrintInteractionController.shared
        let renderer = MultiLanguageFooterPrintRenderer(footerTexts: footerTexts, languageFonts: languageFonts)
        let printFormatter = UIMarkupTextPrintFormatter(markupText: htmlContent)
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = jobName
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printPageRenderer = renderer
        printController.present(from: viewController.view.frame, in: viewController.view, animated: true) { _, completed, error in
            completion(completed, error)
        }
    }
}

private extension NSAttributedString {
    func getPrintFormatter() -> UISimpleTextPrintFormatter {
        let formatter = UISimpleTextPrintFormatter(attributedText: self)
        formatter.perPageContentInsets = UIEdgeInsets(top: 20, left: 20, bottom: 80, right: 20)
        return formatter
    }
}
