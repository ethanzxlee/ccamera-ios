//
//  SelectiveColorFilter.swift
//  CCamera
//
//  Created by Zhe Xian Lee on 20/01/2017.
//  Copyright © 2017 Zhe Xian Lee. All rights reserved.
//

import CoreImage

final class SelectiveColorFilter : CIFilter {
  
    private static let kernelFilename = "SelectiveColorFilterKernel"
    
    private static let kernelFileType = "cikernel"
    
    private(set) var kernel : CIColorKernel?
    
    var inputImage: CIImage?
    
    var selectedColor: CIColor?
    
    override init() {
        super.init()
        
        // Get the path of the kernel's code
        if let url = Bundle.main.url(forResource: SelectiveColorFilter.kernelFilename, withExtension: SelectiveColorFilter.kernelFileType) {
            do {
                // Get the content of the code as a string
                let kernelString = try String(contentsOf: url)
                
                // Initialize the kernel
                kernel = CIColorKernel(string: kernelString)
            } catch let error {
                print(error)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // Get the path of the kernel's code
        if let url = Bundle.main.url(forResource: SelectiveColorFilter.kernelFilename, withExtension: SelectiveColorFilter.kernelFileType) {
            do {
                // Get the content of the code as a string
                let kernelString = try String(contentsOf: url)
                
                // Initialize the kernel
                kernel = CIColorKernel(string: kernelString)
            } catch let error {
                print(error)
            }
        }
    }
    
    
    override var outputImage: CIImage? {
        guard
            let inputImage = inputImage,
            let kernel = kernel
        else {
            return nil
        }
        
        if selectedColor == nil {
            let args = [inputImage as AnyObject, 0, 0.5] as [Any]
            return kernel.apply(withExtent: inputImage.extent, arguments: args)
        }
        else {
            let args = [inputImage as AnyObject, 0, 0] as [Any]
            return kernel.apply(withExtent: inputImage.extent, arguments: args)
        }
        
    }
}
