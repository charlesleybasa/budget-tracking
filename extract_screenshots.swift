import Foundation

let xcresultPath = "build_ios/TestResults.xcresult"
let outPath = "ios/Pesolita/StoreAssets/build"

func run(_ args: String...) -> Data {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    task.arguments = ["xcresulttool"] + args
    let outURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: nil)
    let handle = try! FileHandle(forWritingTo: outURL)
    task.standardOutput = handle
    try! task.run()
    task.waitUntilExit()
    handle.closeFile()
    let data = try! Data(contentsOf: outURL)
    try? FileManager.default.removeItem(at: outURL)
    return data
}

let getJSON = run("get", "--legacy", "--path", xcresultPath, "--format", "json")
guard let json = try? JSONSerialization.jsonObject(with: getJSON) as? [String: Any],
      let actions = json["actions"] as? [String: Any],
      let values = actions["_values"] as? [[String: Any]] else {
    print("Failed to parse main json")
    exit(1)
}

var attachments = [(name: String, id: String)]()

func traverse(_ obj: Any) {
    if let dict = obj as? [String: Any] {
        if dict["_type"] as? [String: String] == ["_name": "ActionTestAttachment"],
           let nameObj = dict["name"] as? [String: Any],
           let nameStr = nameObj["_value"] as? String,
           let payloadRef = dict["payloadRef"] as? [String: Any],
           let idObj = payloadRef["id"] as? [String: Any],
           let idStr = idObj["_value"] as? String {
            attachments.append((nameStr, idStr))
        }
        for value in dict.values {
            traverse(value)
        }
    } else if let arr = obj as? [Any] {
        for value in arr {
            traverse(value)
        }
    }
}

var testsRefID = ""
for value in values {
    if let actionResult = value["actionResult"] as? [String: Any],
       let testsRef = actionResult["testsRef"] as? [String: Any],
       let id = testsRef["id"] as? [String: Any],
       let v = id["_value"] as? String {
        testsRefID = v
        
        print("Found testsRef: \(testsRefID)")
        let testsJSON = run("get", "--legacy", "--path", xcresultPath, "--format", "json", "--id", testsRefID)
        guard let testsDict = try? JSONSerialization.jsonObject(with: testsJSON) as? [String: Any] else {
            print("Failed to parse tests JSON")
            continue
        }
        traverse(testsDict)
    }
}
print("Attachments found: \(attachments.count)")
for att in attachments {
    if att.name.contains("-") { // Filtering for our specific named screenshots
        print("Extracting \(att.name)")
        let outURL = URL(fileURLWithPath: outPath).appendingPathComponent(att.name + ".png")
        try? FileManager.default.removeItem(at: outURL)
        let _ = run("export", "--legacy", "--type", "file", "--path", xcresultPath, "--id", att.id, "--output-path", outURL.path)
    }
}
