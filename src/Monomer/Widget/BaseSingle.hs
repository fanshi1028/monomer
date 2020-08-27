{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}

module Monomer.Widget.BaseSingle (
  Single(..),
  createSingle
) where

import Control.Applicative ((<|>))
import Control.Monad
import Data.Default
import Data.Maybe
import Data.Sequence ((|>))
import Data.Typeable (Typeable, cast)

import Monomer.Common.Geometry
import Monomer.Common.Tree
import Monomer.Event.Core
import Monomer.Event.Types
import Monomer.Graphics.Renderer
import Monomer.Widget.Internal
import Monomer.Widget.Types
import Monomer.Widget.Util

type SingleInitHandler s e
  = WidgetEnv s e
  -> WidgetInstance s e
  -> WidgetResult s e

type SingleMergeHandler s e
  = WidgetEnv s e
  -> Maybe WidgetState
  -> WidgetInstance s e
  -> WidgetResult s e

type SingleDisposeHandler s e
  = WidgetEnv s e
  -> WidgetInstance s e
  -> WidgetResult s e

type SingleGetStateHandler s e
  = WidgetEnv s e
  -> Maybe WidgetState

type SingleFindNextFocusHandler s e
  = WidgetEnv s e
  -> Path
  -> WidgetInstance s e
  -> Maybe Path

type SingleFindByPointHandler s e
  = WidgetEnv s e
  -> Path
  -> Point
  -> WidgetInstance s e
  -> Maybe Path

type SingleEventHandler s e
  = WidgetEnv s e
  -> Path
  -> SystemEvent
  -> WidgetInstance s e
  -> Maybe (WidgetResult s e)

type SingleMessageHandler s e
  = forall i . Typeable i
  => WidgetEnv s e
  -> Path
  -> i
  -> WidgetInstance s e
  -> Maybe (WidgetResult s e)

type SingleGetSizeReqHandler s e
  = WidgetEnv s e
  -> WidgetInstance s e
  -> SizeReq

type SingleResizeHandler s e
  = WidgetEnv s e
  -> Rect
  -> Rect
  -> WidgetInstance s e
  -> WidgetInstance s e

type SingleRenderHandler s e
  =  Renderer
  -> WidgetEnv s e
  -> WidgetInstance s e
  -> IO ()

data Single s e = Single {
  singleInit :: SingleInitHandler s e,
  singleMerge :: SingleMergeHandler s e,
  singleDispose :: SingleDisposeHandler s e,
  singleGetState :: SingleGetStateHandler s e,
  singleFindNextFocus :: SingleFindNextFocusHandler s e,
  singleFindByPoint :: SingleFindByPointHandler s e,
  singleHandleEvent :: SingleEventHandler s e,
  singleHandleMessage :: SingleMessageHandler s e,
  singleGetSizeReq :: SingleGetSizeReqHandler s e,
  singleResize :: SingleResizeHandler s e,
  singleRender :: SingleRenderHandler s e
}

instance Default (Single s e) where
  def = Single {
    singleInit = defaultInit,
    singleMerge = defaultMerge,
    singleDispose = defaultDispose,
    singleGetState = defaultGetState,
    singleFindNextFocus = defaultFindNextFocus,
    singleFindByPoint = defaultFindByPoint,
    singleHandleEvent = defaultHandleEvent,
    singleHandleMessage = defaultHandleMessage,
    singleGetSizeReq = defaultGetSizeReq,
    singleResize = defaultResize,
    singleRender = defaultRender
  }

createSingle :: Single s e -> Widget s e
createSingle Single{..} = Widget {
  widgetInit = singleInit,
  widgetMerge = mergeWrapper singleMerge,
  widgetDispose = singleDispose,
  widgetGetState = singleGetState,
  widgetFindNextFocus = singleFindNextFocus,
  widgetFindByPoint = singleFindByPoint,
  widgetHandleEvent = handleEventWrapper singleHandleEvent,
  widgetHandleMessage = singleHandleMessage,
  widgetUpdateSizeReq = updateSizeReqWrapper singleGetSizeReq,
  widgetResize = singleResize,
  widgetRender = singleRender
}

defaultInit :: SingleInitHandler s e
defaultInit _ widgetInst = resultWidget widgetInst

defaultMerge :: SingleMergeHandler s e
defaultMerge wenv oldState newInstance = resultWidget newInstance

defaultDispose :: SingleDisposeHandler s e
defaultDispose _ widgetInst = resultWidget widgetInst

defaultGetState :: SingleGetStateHandler s e
defaultGetState _ = Nothing

mergeWrapper
  :: SingleMergeHandler s e
  -> WidgetEnv s e
  -> WidgetInstance s e
  -> WidgetInstance s e
  -> WidgetResult s e
mergeWrapper mergeHandler wenv oldInstance newInstance = result where
  oldState = widgetGetState (_wiWidget oldInstance) wenv
  result = mergeHandler wenv oldState newInstance

defaultFindNextFocus :: SingleFindNextFocusHandler s e
defaultFindNextFocus wenv startFrom widgetInst
  | isFocusCandidate startFrom widgetInst = Just (_wiPath widgetInst)
  | otherwise = Nothing

defaultFindByPoint :: SingleFindByPointHandler s e
defaultFindByPoint wenv path point widgetInst = Just (_wiPath widgetInst)

defaultHandleEvent :: SingleEventHandler s e
defaultHandleEvent wenv target evt widgetInst = Nothing

handleEventWrapper
  :: SingleEventHandler s e
  -> WidgetEnv s e
  -> Path
  -> SystemEvent
  -> WidgetInstance s e
  -> Maybe (WidgetResult s e)
handleEventWrapper handler wenv target evt inst = newResult where
  newResult = handleStyleChange handler wenv target evt inst

defaultHandleMessage :: SingleMessageHandler s e
defaultHandleMessage wenv target message widgetInst = Nothing

defaultGetSizeReq :: SingleGetSizeReqHandler s e
defaultGetSizeReq wenv widgetInst = def

updateSizeReqWrapper
  :: SingleGetSizeReqHandler s e
  -> WidgetEnv s e
  -> WidgetInstance s e
  -> WidgetInstance s e
updateSizeReqWrapper handler wenv inst = newInst where
  newInst = inst {
    _wiSizeReq = handler wenv inst
  }

defaultResize :: SingleResizeHandler s e
defaultResize wenv viewport renderArea widgetInst = widgetInst {
    _wiViewport = viewport,
    _wiRenderArea = renderArea
  }

defaultRender :: SingleRenderHandler s e
defaultRender renderer wenv widgetInst = return ()
