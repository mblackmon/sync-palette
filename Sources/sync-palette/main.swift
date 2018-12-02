import AppKit

//MARK: - Writing to console
class Console {
    func printHelp(){
        let help =  """
        sync-palette is used to generate color palette files (*.clr) for your Mac.

        Options:
            -i, --in        Required, a text file with lines of consiting of hex values and names ("#BB8954 Dark Khaki")
            -o, --out       A genrated macOS Palette file.  Default value is Generated Colors.clr
            -s, --swift     If specified, some very basic swift file generation.  See readme.
            --help, help    This message right here
        """
        write(help)
    }
    
    enum OutputType {
        case error
        case standard
    }
    
    func write(_ message: String, to : OutputType = .standard){
        switch to {
        case .standard: print(message)
        case .error: fputs("\(message)\n", stderr)
        }
    }
    
    func exitWith(_ message: String){
        write(message, to: .error)
        exit(EXIT_FAILURE)
    }
}
let console = Console()

//MARK: -  Configuration and parsing CLI args
enum CLIOption {
    case inFile(String)
    case hexOutFile(String)
    case paletteOutFile(String)
    case swiftOutFile(String)
    case help
    case none(String)
    
    static func generateOption(flag: String, value: String ) -> CLIOption {
        switch flag.trimmingCharacters(in: .whitespaces) {
        case "-i", "--in": return .inFile(value)
        case "-o", "--out": return .paletteOutFile(value)
        case "-s", "--swift": return .swiftOutFile(value)
        case "--help", "help": return help
        default:
            return .none(flag)
        }
    }
    
}

struct RunConfiguration {
    
    let infile: String
    let paletteName: String?
    var swiftFileName: String?
    
    init(infile: String, paletteName: String?, swiftFileName: String? ){
        self.infile = infile
        self.paletteName = paletteName
        self.swiftFileName = swiftFileName
    }
    
    class RunConfigurationBuilder {
        var fileName: String?
        var paletteName : String? = nil
        var swiftFileName : String? = nil
        
        var isRunnable : Bool {
            get {
                return nil != fileName
            }
        }
    }
    
    init?(flags: [String]) {
        var options = [CLIOption]()
        if flags.contains("help") || flags.contains("--help"){
            console.printHelp()
            exit(EXIT_SUCCESS)
        }
        for index in stride(from: 1, to: flags.count, by: 2){
            let flag : CLIOption = CLIOption.generateOption(flag: flags[index], value: flags[index + 1])
            if case .none(_) = flag  {
                console.exitWith("Unrecognized flag: \(flag)")
            }
            options.append(flag)
        }
        let builder = RunConfigurationBuilder()
        for case let .inFile(fname) in options{
            builder.fileName = fname
        }
        for case let .paletteOutFile(pname) in options{
            builder.paletteName = pname
        }
        for case let .swiftOutFile(swiftName) in options {
            builder.swiftFileName = swiftName
        }
        
        if(!builder.isRunnable){
            //FIXME: print help
            console.exitWith("No input file specified.  Use the --in paramter to specify a file, or --help for more info")
        }
        
        self.init(infile: builder.fileName!, paletteName:builder.paletteName, swiftFileName: builder.swiftFileName)
    }
    
}

//MARK:  Regex function
func matches(for regex: String, in text: String) -> [String] {
    do {
        let regex = try NSRegularExpression(pattern: regex, options: .dotMatchesLineSeparators)
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        return results.map { nsString.substring(with: $0.range)}
    } catch let error {
        print("invalid regex: \(error.localizedDescription)")
        return []
    }
}

//MARK: - Hex <--> Color functions
func hexStringToUIColor (hex:String) -> NSColor? {
    var colorString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    if colorString.hasPrefix("#") {
        colorString.remove(at: colorString.startIndex)
    }
    if colorString.count != 6 {
        return nil
    }
    
    var rgbValue:UInt32 = 0
    Scanner(string: colorString).scanHexInt32(&rgbValue)
    
    return NSColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpaceName(NSColorSpaceName.calibratedRGB) else {
            return "FFFFFF"
        }
        let red = Int(round(rgbColor.redComponent * 0xFF))
        let green = Int(round(rgbColor.greenComponent * 0xFF))
        let blue = Int(round(rgbColor.blueComponent * 0xFF))
        let hexString = NSString(format: "#%02X%02X%02X", red, green, blue)
        return hexString as String
    }
}

//MARK: String helpers

extension String {
    func lowerCasingFirstLetter() -> String {
        let first = String(self.prefix(1)).lowercased()
        let other = String(self.dropFirst())
        return first + other
    }
}


//MARK: Script Specific functions

let regex = "^\\s*#?[A-Za-z0-9]{6}\\s+"
func readHexFile(_ filePath:String, _ listName: String) -> NSColorList?{
    guard let fileString = try? NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue) else {
        return nil
    }
    let lines = fileString.components(separatedBy: .newlines)
    let tuples = lines.compactMap { (eachLine: String) -> (NSColor, String)? in
        let hexes = matches(for: regex, in: eachLine)
        if let firstHex = hexes.first, hexes.count == 1,
            let realColor = hexStringToUIColor(hex:firstHex) {
            let colorName = eachLine.replacingOccurrences(of: firstHex, with: "").trimmingCharacters(in: .whitespaces)
            return (realColor, colorName)
        } else {
            return nil
        }
    }
    let colorList = NSColorList(name: listName)
    for tuple in tuples.reversed() {
        colorList.insertColor(tuple.0, key: tuple.1, at: 0)
    }
    return colorList
}

func export(_ colorList: NSColorList,toColorFile destination:String?){
    if colorList.write(toFile:destination) == false  {
        console.write("couldn't save palette file", to: .error)
        exit(EXIT_FAILURE)
    }
}

let caseEntryRegex = "//KEYCASE_START(.*)//KEYCASE_END"
let dictEntryRegex = "//DICTIONARY_START(.*)//DICTIONARY_END"
func export(_ colorList: NSColorList,toSwiftFile destination:String?){
    guard let destination = destination, let fileString = try? NSString(contentsOfFile: destination, encoding: String.Encoding.utf8.rawValue) else {
        return
    }
    //Do the case statements
    var caseEntries = colorList.allKeys.map { (s : String) -> String in
        return "\tcase \(s.replacingOccurrences(of: " ", with: "").lowerCasingFirstLetter())"
        }.reduce("") { (r: String, s:String) -> String in
            return "\(r)\n\(s)"
    }
    //put the tags back in
    caseEntries = "//KEYCASE_START\n" + caseEntries + "\n\t//KEYCASE_END"
    var newFileString = ""
    for matchString in matches(for: caseEntryRegex, in: fileString as String){
        newFileString = fileString.replacingOccurrences(of: matchString, with: caseEntries)
    }
    
    //Now do the dictionary
    var dictText = colorList.allKeys.compactMap { (entry: String) -> String? in
        if let color = colorList.color(withKey: entry){
            let uiColorString = "UIColor(red: \(color.redComponent), green: \(color.greenComponent), blue: \(color.blueComponent), alpha: 1.0)"
            let colorName = "." + entry.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces).lowerCasingFirstLetter()
            return "\(colorName) : \(uiColorString),"
        }
        return nil
        }.reduce("") { (partial: String, next : String) -> String in
            return "\(partial)\n\t\(next)"
    }
    dictText = "//DICTIONARY_START\n\t" + dictText + "\n\t//DICTIONARY_END"
    
    matches(for: dictEntryRegex, in: newFileString as String).forEach {
        newFileString = newFileString.replacingOccurrences(of: $0, with: dictText)
    }
    
    do {
        try newFileString.write(toFile: destination, atomically: true, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
    }
    catch(let e){
        console.write("Error writing to file \(e)", to: .error)
    }
    
}

//MARK: - Main script

if let config = RunConfiguration(flags: CommandLine.arguments) {
    let paletteFilename = config.paletteName ?? "./Generated Colors.clr"
    let schemeName = paletteFilename.hasSuffix(".clr") ? String(paletteFilename.dropLast(4)) : paletteFilename
    guard let colorEntries = readHexFile(config.infile, schemeName) else {
        console.exitWith("Couldn't understand the colors from the given hex file")
        exit(EXIT_FAILURE)
    }
    export(colorEntries, toColorFile:paletteFilename)
    if let swiftFileName = config.swiftFileName {
        export(colorEntries, toSwiftFile:swiftFileName)
    }
} else {
    console.exitWith("Unknown error")
}





