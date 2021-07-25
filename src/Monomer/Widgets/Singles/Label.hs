{-|
Module      : Monomer.Widgets.Singles.Label
Copyright   : (c) 2018 Francisco Vallarino
License     : BSD-3-Clause (see the LICENSE file)
Maintainer  : fjvallarino@gmail.com
Stability   : experimental
Portability : non-portable

Label widget, with support for multiline text.

Configs:

- trimSpaces: whether to remove leading/trailing spaces in the caption.
- ellipsis: if ellipsis should be used for overflown text.
- multiLine: if text may be split in multiple lines.
- maxLines: maximum number of text lines to show.
- ignoreTheme: whether to load default style from theme or start empty.
- resizeFactor: flexibility to have more or less spaced assigned.
- resizeFactorW: flexibility to have more or less horizontal spaced assigned.
- resizeFactorH: flexibility to have more or less vertical spaced assigned.
-}
{-# LANGUAGE DeriveGeneric #-}

module Monomer.Widgets.Singles.Label (
  LabelCfg(..),
  label,
  label_,
  labelS,
  labelS_
) where

import Control.Applicative ((<|>))
import Control.Lens ((&), (^.), (.~), (^?), non, ix)
import Control.Monad (forM_)
import Data.Default
import Data.Maybe
import Data.Sequence (Seq(..))
import Data.Text (Text)
import GHC.Generics

import qualified Data.Sequence as Seq
import qualified Data.Text as T

import Monomer.Widgets.Single

import qualified Monomer.Lens as L

data LabelCfg s e = LabelCfg {
  _lscIgnoreTheme :: Maybe Bool,
  _lscTextTrim :: Maybe Bool,
  _lscTextEllipsis :: Maybe Bool,
  _lscTextMultiLine :: Maybe Bool,
  _lscTextMaxLines :: Maybe Int,
  _lscFactorW :: Maybe Double,
  _lscFactorH :: Maybe Double,
  _lscActiveStyle :: Maybe (WidgetEnv s e -> WidgetNode s e -> StyleState)
}

instance Default (LabelCfg s e) where
  def = LabelCfg {
    _lscIgnoreTheme = Nothing,
    _lscTextTrim = Nothing,
    _lscTextEllipsis = Nothing,
    _lscTextMultiLine = Nothing,
    _lscTextMaxLines = Nothing,
    _lscFactorW = Nothing,
    _lscFactorH = Nothing,
    _lscActiveStyle = Nothing
  }

instance Semigroup (LabelCfg s e) where
  (<>) l1 l2 = LabelCfg {
    _lscIgnoreTheme = _lscIgnoreTheme l2 <|> _lscIgnoreTheme l1,
    _lscTextTrim = _lscTextTrim l2 <|> _lscTextTrim l1,
    _lscTextEllipsis = _lscTextEllipsis l2 <|> _lscTextEllipsis l1,
    _lscTextMultiLine = _lscTextMultiLine l2 <|> _lscTextMultiLine l1,
    _lscTextMaxLines = _lscTextMaxLines l2 <|> _lscTextMaxLines l1,
    _lscFactorW = _lscFactorW l2 <|> _lscFactorW l1,
    _lscFactorH = _lscFactorH l2 <|> _lscFactorH l1,
    _lscActiveStyle = _lscActiveStyle l2 <|> _lscActiveStyle l1
  }

instance Monoid (LabelCfg s e) where
  mempty = def

instance CmbIgnoreTheme (LabelCfg s e) where
  ignoreTheme_ ignore = def {
    _lscIgnoreTheme = Just ignore
  }

instance CmbTrimSpaces (LabelCfg s e) where
  trimSpaces_ trim = def {
    _lscTextTrim = Just trim
  }

instance CmbEllipsis (LabelCfg s e) where
  ellipsis_ ellipsis = def {
    _lscTextEllipsis = Just ellipsis
  }

instance CmbMultiLine (LabelCfg s e) where
  multiLine_ multi = def {
    _lscTextMultiLine = Just multi
  }

instance CmbMaxLines (LabelCfg s e) where
  maxLines count = def {
    _lscTextMaxLines = Just count
  }

instance CmbResizeFactor (LabelCfg s e) where
  resizeFactor s = def {
    _lscFactorW = Just s,
    _lscFactorH = Just s
  }

instance CmbResizeFactorDim (LabelCfg s e) where
  resizeFactorW w = def {
    _lscFactorW = Just w
  }
  resizeFactorH h = def {
    _lscFactorH = Just h
  }

data LabelState = LabelState {
  _lstCaption :: Text,
  _lstTextStyle :: Maybe TextStyle,
  _lstTextRect :: Rect,
  _lstTextLines :: Seq TextLine,
  _lstPrevResize :: (Int, Bool)
} deriving (Eq, Show, Generic)

-- | Creates a label using the provided 'Text'.
label :: Text -> WidgetNode s e
label caption = label_ caption def

-- | Creates a label using the provided 'Text'. Accepts config.
label_ :: Text -> [LabelCfg s e] -> WidgetNode s e
label_ caption configs = defaultWidgetNode "label" widget where
  config = mconcat configs
  state = LabelState caption Nothing def Seq.Empty (0, False)
  widget = makeLabel config state

-- | Creates a label using the 'Show' instance of the type.
labelS :: Show a => a -> WidgetNode s e
labelS caption = labelS_ caption def

-- | Creates a label using the 'Show' instance of the type. Accepts config.
labelS_ :: Show a => a -> [LabelCfg s e] -> WidgetNode s e
labelS_ caption configs = label_ (T.pack . show $ caption) configs

makeLabel :: LabelCfg s e -> LabelState -> Widget s e
makeLabel config state = widget where
  baseWidget = createSingle state def {
    singleGetBaseStyle = getBaseStyle,
    singleInit = init,
    singleMerge = merge,
    singleGetSizeReq = getSizeReq,
    singleResize = resize
  }
  widget = baseWidget {
    widgetRender = render
  }

  ignoreTheme = _lscIgnoreTheme config == Just True
  trim
    | _lscTextTrim config == Just True = TrimSpaces
    | otherwise = KeepSpaces
  overflow
    | _lscTextEllipsis config == Just True = Ellipsis
    | otherwise = ClipText
  mode
    | _lscTextMultiLine config == Just True = MultiLine
    | otherwise = SingleLine
  maxLines = _lscTextMaxLines config
  labelActiveStyle = fromMaybe activeStyle (_lscActiveStyle config)
  LabelState caption textStyle textRect textLines prevResize = state

  getBaseStyle wenv node
    | ignoreTheme = Nothing
    | otherwise = Just $ collectTheme wenv L.labelStyle

  init wenv node = resultNode newNode where
    style = labelActiveStyle wenv node
    newState = state {
      _lstTextStyle = style ^. L.text
    }
    newNode = node
      & L.widget .~ makeLabel config newState

  merge wenv newNode oldNode oldState = result where
    style = labelActiveStyle wenv newNode
    newTextStyle = style ^. L.text

    captionChanged = _lstCaption oldState /= caption
    styleChanged = _lstTextStyle oldState /= newTextStyle
    changeReq = captionChanged || styleChanged
    -- This is used in resize to know if glyphs have to be recalculated
    newRect
      | changeReq = def
      | otherwise = _lstTextRect oldState
    newState = oldState {
      _lstCaption = caption,
      _lstTextRect = newRect,
      _lstTextStyle = newTextStyle
    }

    reqs = [ ResizeWidgets | changeReq ]
    resNode = newNode
      & L.widget .~ makeLabel config newState
    result = resultReqs resNode reqs

  getSizeReq wenv node = (sizeW, sizeH) where
    ts = wenv ^. L.timestamp
    caption = _lstCaption state
    prevResize = _lstPrevResize state
    style = labelActiveStyle wenv node

    cw = getContentArea style node ^. L.w
    defaultFactor
      | mode == MultiLine = 1
      | overflow == Ellipsis = 0.01
      | otherwise = 0

    targetW
      | mode == MultiLine && prevResize == (ts, True) = Just cw
      | otherwise = fmap sizeReqMaxBounded (style ^. L.sizeReqW)
    Size w h = getTextSize_ wenv style mode trim targetW maxLines caption

    factorW = fromMaybe defaultFactor (_lscFactorW config)
    factorH = fromMaybe defaultFactor (_lscFactorH config)

    sizeW
      | abs factorW < 0.01 = fixedSize w
      | otherwise = flexSize w factorW
    sizeH
      | abs factorH < 0.01 = fixedSize h
      | otherwise = flexSize h factorH

  resize wenv node viewport = result where
    fontMgr = wenv ^. L.fontManager
    ts = wenv ^. L.timestamp
    style = labelActiveStyle wenv node
    crect = fromMaybe def (removeOuterBounds style viewport)
    newTextStyle = style ^. L.text

    Rect px py pw ph = textRect
    Rect _ _ cw ch = crect
    size = Size cw ch
    alignRect = Rect 0 0 cw ch

    fittedLines
      = fitTextToSize fontMgr style overflow mode trim maxLines size caption
    newTextLines = alignTextLines style alignRect fittedLines

    newGlyphsReq = pw /= cw || ph /= ch || textStyle /= newTextStyle
    newLines
      | not newGlyphsReq = textLines
      | otherwise = newTextLines

    (prevTs, prevStep) = prevResize
    needsSndResize = mode == MultiLine && (prevTs /= ts || not prevStep)

    newState = state {
      _lstTextStyle = newTextStyle,
      _lstTextRect = crect,
      _lstTextLines = newLines,
      _lstPrevResize = (ts, needsSndResize && prevTs == ts)
    }
    newNode = node
      & L.widget .~ makeLabel config newState
    result = resultReqs newNode [ResizeWidgets | needsSndResize]

  render wenv node renderer = do
    drawInScissor renderer True scissorVp $
      drawStyledAction renderer viewport style $ \(Rect cx cy _ _) ->
        drawInTranslation renderer (Point cx cy) $
          forM_ textLines (drawTextLine renderer style)
    where
      style = labelActiveStyle wenv node
      viewport = node ^. L.info . L.viewport
      textMetrics = textLines ^? ix 0 . L.metrics
      desc = abs (textMetrics ^. non def . L.desc)
      scissorVp = viewport
        & L.y .~ (viewport ^. L.y - desc)
        & L.h .~ (viewport ^. L.h + desc)
