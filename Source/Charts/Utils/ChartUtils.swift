//
//  Utils.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(Cocoa)
import Cocoa
#endif

extension Comparable
{
    func clamped(to range: ClosedRange<Self>) -> Self
    {
        if self > range.upperBound
        {
            return range.upperBound
        }
        else if self < range.lowerBound
        {
            return range.lowerBound
        }
        else
        {
            return self
        }
    }
}

extension FloatingPoint
{
    var DEG2RAD: Self
    {
        return self * .pi / 180
    }

    var RAD2DEG: Self
    {
        return self * 180 / .pi
    }

    /// - Note: Value must be in degrees
    /// - Returns: An angle between 0.0 < 360.0 (not less than zero, less than 360)
    var normalizedAngle: Self
    {
        let angle = truncatingRemainder(dividingBy: 360)
        return (sign == .minus) ? angle + 360 : angle
    }
}

extension CGSize
{
    func rotatedBy(degrees: CGFloat) -> CGSize
    {
        let radians = degrees.DEG2RAD
        return rotatedBy(radians: radians)
    }

    func rotatedBy(radians: CGFloat) -> CGSize
    {
        return CGSize(
            width: abs(width * cos(radians)) + abs(height * sin(radians)),
            height: abs(width * sin(radians)) + abs(height * cos(radians))
        )
    }
}

extension Double
{
    /// Rounds the number to the nearest multiple of it's order of magnitude, rounding away from zero if halfway.
    func roundedToNextSignficant() -> Double
    {
        guard
            !isInfinite,
            !isNaN,
            self != 0
            else { return self }

        let d = ceil(log10(self < 0 ? -self : self))
        let pw = 1 - Int(d)
        let magnitude = pow(10.0, Double(pw))
        let shifted = (self * magnitude).rounded()
        return shifted / magnitude
    }

    var decimalPlaces: Int
    {
        guard
            !isNaN,
            !isInfinite,
            self != 0.0
            else { return 0 }

        let i = self.roundedToNextSignficant()

        guard
            !i.isInfinite,
            !i.isNaN
            else { return 0 }

        return Int(ceil(-log10(i))) + 2
    }
}

extension CGPoint
{
    /// Calculates the position around a center point, depending on the distance from the center, and the angle of the position around the center.
    func moving(distance: CGFloat, atAngle angle: CGFloat) -> CGPoint
    {
        return CGPoint(x: x + distance * cos(angle.DEG2RAD),
                       y: y + distance * sin(angle.DEG2RAD))
    }
}

open class ChartUtils
{
    private static var _defaultValueFormatter: IValueFormatter = ChartUtils.generateDefaultValueFormatter()
    
    open class func drawImage(
        context: CGContext,
        image: NSUIImage,
        x: CGFloat,
        y: CGFloat,
        size: CGSize)
    {
        var drawOffset = CGPoint()
        drawOffset.x = x - (size.width / 2)
        drawOffset.y = y - (size.height / 2)
        
        NSUIGraphicsPushContext(context)
        
        if image.size.width != size.width && image.size.height != size.height
        {
            let key = "resized_\(size.width)_\(size.height)"
            
            // Try to take scaled image from cache of this image
            var scaledImage = objc_getAssociatedObject(image, key) as? NSUIImage
            if scaledImage == nil
            {
                // Scale the image
                NSUIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                
                image.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
                
                scaledImage = NSUIGraphicsGetImageFromCurrentImageContext()
                NSUIGraphicsEndImageContext()
                
                // Put the scaled image in a cache owned by the original image
                objc_setAssociatedObject(image, key, scaledImage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            scaledImage?.draw(in: CGRect(origin: drawOffset, size: size))
        }
        else
        {
            image.draw(in: CGRect(origin: drawOffset, size: size))
        }
        
        NSUIGraphicsPopContext()
    }
    
    open class func drawText(context: CGContext, text: String, point: CGPoint, align: NSTextAlignment, attributes: [NSAttributedString.Key : Any]?)
    {
        var point = point
        
        if align == .center
        {
            point.x -= text.size(withAttributes: attributes).width / 2.0
        }
        else if align == .right
        {
            point.x -= text.size(withAttributes: attributes).width
        }
        
        NSUIGraphicsPushContext(context)
        
        (text as NSString).draw(at: point, withAttributes: attributes)
        
        NSUIGraphicsPopContext()
    }
    
    open class func drawText(context: CGContext, text: String, point: CGPoint, attributes: [NSAttributedString.Key : Any]?, anchor: CGPoint, angleRadians: CGFloat)
    {
        var drawOffset = CGPoint()
        
        NSUIGraphicsPushContext(context)
        
        if angleRadians != 0.0
        {
            let size = text.size(withAttributes: attributes)
            
            // Move the text drawing rect in a way that it always rotates around its center
            drawOffset.x = -size.width * 0.5
            drawOffset.y = -size.height * 0.5
            
            var translate = point
            
            // Move the "outer" rect relative to the anchor, assuming its centered
            if anchor.x != 0.5 || anchor.y != 0.5
            {
                let rotatedSize = size.rotatedBy(radians: angleRadians)
                
                translate.x -= rotatedSize.width * (anchor.x - 0.5)
                translate.y -= rotatedSize.height * (anchor.y - 0.5)
            }
            
            context.saveGState()
            context.translateBy(x: translate.x, y: translate.y)
            context.rotate(by: angleRadians)
            
            (text as NSString).draw(at: drawOffset, withAttributes: attributes)
            
            context.restoreGState()
        }
        else
        {
            if anchor.x != 0.0 || anchor.y != 0.0
            {
                let size = text.size(withAttributes: attributes)
                
                drawOffset.x = -size.width * anchor.x
                drawOffset.y = -size.height * anchor.y
            }
            
            drawOffset.x += point.x
            drawOffset.y += point.y
            
            (text as NSString).draw(at: drawOffset, withAttributes: attributes)
        }
        
        NSUIGraphicsPopContext()
    }
    
    internal class func drawMultilineText(context: CGContext, text: String, knownTextSize: CGSize, point: CGPoint, attributes: [NSAttributedString.Key : Any]?, constrainedToSize: CGSize, anchor: CGPoint, angleRadians: CGFloat)
    {
        var rect = CGRect(origin: CGPoint(), size: knownTextSize)
        
        NSUIGraphicsPushContext(context)
        
        if angleRadians != 0.0
        {
            // Move the text drawing rect in a way that it always rotates around its center
            rect.origin.x = -knownTextSize.width * 0.5
            rect.origin.y = -knownTextSize.height * 0.5
            
            var translate = point
            
            // Move the "outer" rect relative to the anchor, assuming its centered
            if anchor.x != 0.5 || anchor.y != 0.5
            {
                let rotatedSize = knownTextSize.rotatedBy(radians: angleRadians)
                
                translate.x -= rotatedSize.width * (anchor.x - 0.5)
                translate.y -= rotatedSize.height * (anchor.y - 0.5)
            }
            
            context.saveGState()
            context.translateBy(x: translate.x, y: translate.y)
            context.rotate(by: angleRadians)
            
            (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
            
            context.restoreGState()
        }
        else
        {
            if anchor.x != 0.0 || anchor.y != 0.0
            {
                rect.origin.x = -knownTextSize.width * anchor.x
                rect.origin.y = -knownTextSize.height * anchor.y
            }
            
            rect.origin.x += point.x
            rect.origin.y += point.y
            
            (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        }
        
        NSUIGraphicsPopContext()
    }
    
    internal class func drawMultilineText(context: CGContext, text: String, point: CGPoint, attributes: [NSAttributedString.Key : Any]?, constrainedToSize: CGSize, anchor: CGPoint, angleRadians: CGFloat)
    {
        let rect = text.boundingRect(with: constrainedToSize, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        drawMultilineText(context: context, text: text, knownTextSize: rect.size, point: point, attributes: attributes, constrainedToSize: constrainedToSize, anchor: anchor, angleRadians: angleRadians)
    }

    private class func generateDefaultValueFormatter() -> IValueFormatter
    {
        let formatter = DefaultValueFormatter(decimals: 1)
        return formatter
    }
    
    /// - Returns: The default value formatter used for all chart components that needs a default
    open class func defaultValueFormatter() -> IValueFormatter
    {
        return _defaultValueFormatter
    }
}


//
//  File.swift
//
//
//  Created by Summerweb on 31.03.2022.
//

import Foundation
import CoreGraphics
//
// Запоминаем уже нарисованные лейблы, что бы смешать при пересечении
//
public class DrawnLabels {
    private final var labelsPosition: NSMutableDictionary = [:];
    // На сколько выше сместим лейбл на графике
    private final var Y_PARALLAX: Int = -5;
    private final var X_PARALLAX: Int = 5;
    // Сколько пикселей будем считать за единицу, например если 5, то позиции 103 и 104 приравняем к 105 и будем считать равными
    private final var Y_ROUND: Int = 5;
    private final var X_ROUND: Int = 5;
    // Сколько соседних ячеек проверять на наличиие лейблов справа и слева
    private final var X_NEIGHBORS: Int = 5 * 5;
    // Сколько соседних ячеек проверять на наличиие лейблов сверху и снизу
    private final var Y_NEIGHBORS: Int = 4 * 5;


    private func convertValue(value: Float, positionRound: Int) -> Int {
        let result: Int = Int(round(value / 10));
        let round: Float = value.truncatingRemainder(dividingBy: 10);
        return (result * 10) + (round > Float(positionRound) ? 5 : 0);
    }

    private func searchIntersection(x: Int, y: Int) -> [Int] {
        let startStepX: Int = max(x - X_NEIGHBORS, 0);
        // Ходим по оси X ищем похожих соседей
        var stepX: Int = startStepX;
        while(stepX <= x + X_NEIGHBORS){
            let positionsY: NSMutableSet?? = labelsPosition[stepX] as! NSMutableSet??;
            if (positionsY??.count == nil) {
                stepX += X_ROUND;
                continue;
            }
            let startStepY: Int = max(y + Y_NEIGHBORS, 0);
            let stopStepY: Int = max(y - Y_NEIGHBORS, 0);
            // Если нашли соседа, выходим, т.к. теперь надо начинать поиск заново с новым значением
            var stepY: Int = startStepY;
            while(stepY > stopStepY){
                if((positionsY as! NSMutableSet).contains(stepY)){
                    return [0, Y_PARALLAX];
                }
                stepY -= Y_ROUND;
            }
            stepX += X_ROUND;
        }
        return [0, 0];
    }

    public func add(x: CGFloat, y: CGFloat) -> [CGFloat] {
        var originalValueY: Float = Float( y );
        var convertedValueY: Int = convertValue(value: originalValueY, positionRound: Y_ROUND);
        let convertedValueX: Int = convertValue(value: Float(x), positionRound: X_ROUND);

        var intersectionGap: [Int] = searchIntersection(x: convertedValueX, y: convertedValueY);
        while (intersectionGap[1] != 0) {
            convertedValueY += intersectionGap[1];
            originalValueY += Float(intersectionGap[1]);
            // print("==>>: " + String(Float(x)) + " " + String(Float(y)) + "==> " + String(originalValueY));
            intersectionGap = searchIntersection(x: convertedValueX, y: convertedValueY);
        }

        var positionsY: NSMutableSet?? = labelsPosition[convertedValueX] as! NSMutableSet??;
        // Добавим, если в этой позиции оси Х еще не было лейблов
        if (positionsY??.count == nil) {
            positionsY = NSMutableSet();
            labelsPosition[convertedValueX] = positionsY as Any?;
        }

        // Добавляем новый лейбл
        positionsY!!.add(convertedValueY);
        return [x, CGFloat(originalValueY)];
    }

    public func getData() -> NSMutableDictionary {
        return labelsPosition;
    }
}
