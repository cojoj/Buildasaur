//
//  SSHKeyVerification.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 13/05/15.
//  Copyright (c) 2015 Honza Dvorsky. All rights reserved.
//

import Foundation

public class SSHKeyVerification {
    
    private class func findXcodeDeveloperFolder() -> String {
        
        //first find xcode's developer folder, in case user has a renamed xcode
        let found = Script.run("xcode-select", arguments: ["-p"])
        
        if found.terminationStatus == 0 {
            let path = found.standardOutput.stripTrailingNewline()
            return path
        } else {
            //if that fails, try the standard path
            return "/Applications/Xcode.app/Contents/Developer"
        }
    }
    
    public class func verifyBlueprint(blueprint: NSDictionary) -> Script.ScriptResponse {
        
        //convert dictionary into string
        var serializationError: NSError?
        if let data = NSJSONSerialization.dataWithJSONObject(blueprint, options: NSJSONWritingOptions.allZeros, error: &serializationError) {
            
            let scriptString = NSString(data: data, encoding: NSUTF8StringEncoding)!
            
            let xcodePath = self.findXcodeDeveloperFolder()
            let xcsbridgePath = "\(xcodePath)/usr/bin/xcsbridge"
            let xcsbridgeArgs = "source-control blueprint-preflight --path - --format json"
            let script = "echo '\(scriptString)' | \(xcsbridgePath) \(xcsbridgeArgs)"
            let response = Script.runTemporaryScript(script)
            
            //if return value != 0, something went wrong unexpectedly, just pass up
            if response.terminationStatus != 0 {
                return response
            }
            
            //parse the response as json
            let responseString = response.standardOutput
            var parsingError: NSError?
            if
                let data = responseString.dataUsingEncoding(NSUTF8StringEncoding),
                let obj = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as? NSDictionary
            {
                
                //valid output is an empty dictionary
                if obj.count == 0 {
                    //yay
                    return (0, "Blueprint is valid", "")
                }
                
                //else, we know a key "repository errors" having a sensible error, try to parse it
                if
                    let repositoryErrors = obj["repositoryErrors"] as? NSArray,
                    let errorDict = repositoryErrors.firstObject as? NSDictionary,
                    let errorObject = errorDict["error"] as? NSDictionary,
                    let errorMessage = errorObject["message"] as? String
                {
                    return (1, "", errorMessage)
                } else {
                    return (1, "", obj.description)
                }
                
            } else {
                return (response.terminationStatus, response.standardOutput, "\(response.standardError), error \(parsingError)")
            }
            
        } else {
            return (1, "", "Failed to serialize blueprint")
        }
    }
}



