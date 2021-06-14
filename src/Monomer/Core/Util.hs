{-|
Module      : Monomer.Core.Util
Copyright   : (c) 2018 Francisco Vallarino
License     : BSD-3-Clause (see the LICENSE file)
Maintainer  : fjvallarino@gmail.com
Stability   : experimental
Portability : non-portable

Helper functions for Core types.
-}
{-# LANGUAGE LambdaCase #-}

module Monomer.Core.Util where

import Control.Lens ((&), (^.), (.~), (?~))
import Data.Maybe
import Data.Text (Text)
import Data.Typeable (cast)
import Data.Sequence (Seq(..))

import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import qualified Data.Text as T

import Monomer.Common
import Monomer.Core.Style
import Monomer.Core.WidgetTypes
import Monomer.Helper

import qualified Monomer.Core.Lens as L

-- | Returns the path associated to a given key, if any.
pathFromKey :: WidgetEnv s e -> Text -> Maybe Path
pathFromKey wenv key = fmap (^. L.info . L.path) node where
  node = Map.lookup (WidgetKey key) (wenv ^. L.globalKeys)

-- | Returns the widgetId associated to a given key, if any.
widgetIdFromKey :: WidgetEnv s e -> Text -> Maybe WidgetId
widgetIdFromKey wenv key = fmap (^. L.info . L.widgetId) node where
  node = Map.lookup (WidgetKey key) (wenv ^. L.globalKeys)

-- | Returns the node info associated to a given path.
findWidgetByPath
  :: WidgetEnv s e -> WidgetNode s e -> Path -> Maybe WidgetNodeInfo
findWidgetByPath wenv node target = mnode where
  branch = widgetFindBranchByPath (node ^. L.widget) wenv node target
  mnode = case Seq.lookup (length branch - 1) branch of
    Just child
      | child ^. L.path == target -> Just child
    _ -> Nothing

-- | Helper functions that associates False to Vertical and True to Horizontal.
getLayoutDirection :: Bool -> LayoutDirection
getLayoutDirection False = LayoutVertical
getLayoutDirection True = LayoutHorizontal

-- | Filters user events from a list of WidgetRequests.
eventsFromReqs :: Seq (WidgetRequest s e) -> Seq e
eventsFromReqs reqs = seqCatMaybes mevents where
  mevents = flip fmap reqs $ \case
    RaiseEvent ev -> cast ev
    _ -> Nothing

{-|
Ignore events generated by the parent. Could be used to consume the tab key and
avoid having the focus move to the next widget.
-}
isIgnoreParentEvents :: WidgetRequest s e -> Bool
isIgnoreParentEvents IgnoreParentEvents = True
isIgnoreParentEvents _ = False

-- | Ignore children events. Scroll relies on this to handle click/wheel.
isIgnoreChildrenEvents :: WidgetRequest s e -> Bool
isIgnoreChildrenEvents IgnoreChildrenEvents = True
isIgnoreChildrenEvents _ = False

{-|
The widget content changed and requires a different size. Processed at the end
of the cycle, since several widgets may request it.
-}
isResizeWidgets :: WidgetRequest s e -> Bool
isResizeWidgets ResizeWidgets = True
isResizeWidgets _ = False

{-|
The widget content changed and requires a different size. Processed immediately.
Avoid if possible, since it can affect performance.
-}
isResizeWidgetsImmediate :: WidgetRequest s e -> Bool
isResizeWidgetsImmediate ResizeWidgetsImmediate = True
isResizeWidgetsImmediate _ = False

-- | Moves the focus, optionally indicating a starting widgetId.
isMoveFocus :: WidgetRequest s e -> Bool
isMoveFocus MoveFocus{} = True
isMoveFocus _ = False

-- | Sets the focus to the given widgetId.
isSetFocus :: WidgetRequest s e -> Bool
isSetFocus SetFocus{} = True
isSetFocus _ = False

-- | Requests the clipboard contents. It will be received as a SystemEvent.
isGetClipboard :: WidgetRequest s e -> Bool
isGetClipboard GetClipboard{} = True
isGetClipboard _ = False

-- | Sets the clipboard to the given ClipboardData.
isSetClipboard :: WidgetRequest s e -> Bool
isSetClipboard SetClipboard{} = True
isSetClipboard _ = False

{-|
Sets the viewport which should be remain visible when an on-screen keyboard is
displayed. Required for mobile.
-}
isStartTextInput :: WidgetRequest s e -> Bool
isStartTextInput StartTextInput{} = True
isStartTextInput _ = False

-- | Resets the keyboard viewport,
isStopTextInput :: WidgetRequest s e -> Bool
isStopTextInput StopTextInput{} = True
isStopTextInput _ = False

{-|
Sets a widget as the base target of future events. This is used by the dropdown
component to handle list events (which is on top of everything).
-}
isSetOverlay :: WidgetRequest s e -> Bool
isSetOverlay SetOverlay{} = True
isSetOverlay _ = False

-- | Removes the existing overlay.
isResetOverlay :: WidgetRequest s e -> Bool
isResetOverlay ResetOverlay{} = True
isResetOverlay _ = False

{-|
Sets the current active cursor icon. This acts as a stack, so removing means
going back a step.
-}
isSetCursorIcon :: WidgetRequest s e -> Bool
isSetCursorIcon SetCursorIcon{} = True
isSetCursorIcon _ = False

-- | Removes a cursor icon setting from the stack.
isResetCursorIcon :: WidgetRequest s e -> Bool
isResetCursorIcon ResetCursorIcon{} = True
isResetCursorIcon _ = False

{-|
Sets the current item being dragged and the message it carries. This message is
used by targets to check if they accept it or not.
-}
isStartDrag :: WidgetRequest s e -> Bool
isStartDrag StartDrag{} = True
isStartDrag _ = False

-- | Cancels the current dragging process.
isStopDrag :: WidgetRequest s e -> Bool
isStopDrag StopDrag{} = True
isStopDrag _ = False

{-|
Requests rendering a single frame. Rendering is not done at a fixed rate, in
order to reduce CPU usage. Widgets are responsible of requesting rendering at
points of interest. Mouse and keyboard events automatically generate render
requests, but the result of a WidgetTask does not.
-}
isRenderOnce :: WidgetRequest s e -> Bool
isRenderOnce RenderOnce{} = True
isRenderOnce _ = False

{-|
Useful if a widget requires periodic rendering. An optional maximum number of
frames can be provided.
-}
isRenderEvery :: WidgetRequest s e -> Bool
isRenderEvery RenderEvery{} = True
isRenderEvery _ = False

-- | Stops a previous periodic rendering request.
isRenderStop :: WidgetRequest s e -> Bool
isRenderStop RenderStop{} = True
isRenderStop _ = False

{-|
Requests to exit the application. Can also be used to cancel a previous request
(or a window close).
-}
isExitApplication :: WidgetRequest s e -> Bool
isExitApplication ExitApplication{} = True
isExitApplication _ = False

-- | Performs a "WindowRequest".
isUpdateWindow :: WidgetRequest s e -> Bool
isUpdateWindow UpdateWindow{} = True
isUpdateWindow _ = False

-- | Request a model update. This usually involves lenses and "widgetDataSet".
isUpdateModel :: WidgetRequest s e -> Bool
isUpdateModel UpdateModel{} = True
isUpdateModel _ = False

{-|
Updates the path of a given widget. Both "Monomer.Widgets.Single" and
"Monomer.Widgets.Container" handle this automatically.
-}
isSetWidgetPath :: WidgetRequest s e -> Bool
isSetWidgetPath SetWidgetPath{} = True
isSetWidgetPath _ = False

-- | Clears an association between widgetId and path.
isResetWidgetPath :: WidgetRequest s e -> Bool
isResetWidgetPath ResetWidgetPath{} = True
isResetWidgetPath _ = False

{-|
Raises a user event, which usually will be processed in handleEvent in a
"Monomer.Widgets.Composite" instance.
-}
isRaiseEvent :: WidgetRequest s e -> Bool
isRaiseEvent RaiseEvent{} = True
isRaiseEvent _ = False

{-|
Sends a message to the given widgetId. If the target does not expect the
message's type, it will be ignored.
-}
isSendMessage :: WidgetRequest s e -> Bool
isSendMessage SendMessage{} = True
isSendMessage _ = False

{-|
Runs an asynchronous tasks. It is mandatory to return a message that will be
sent to the task owner (this is the only way to feed data back).
-}
isRunTask :: WidgetRequest s e -> Bool
isRunTask RunTask{} = True
isRunTask _ = False

{-|
Similar to RunTask, but can generate unlimited messages. This is useful for
WebSockets and similar data sources. It receives a function that with which to
send messagess to the producer owner.
-}
isRunProducer :: WidgetRequest s e -> Bool
isRunProducer RunProducer{} = True
isRunProducer _ = False

-- | Checks if the request is either MoveFocus or SetFocus.
isFocusRequest :: WidgetRequest s e -> Bool
isFocusRequest MoveFocus{} = True
isFocusRequest SetFocus{} = True
isFocusRequest _ = False

-- | Checks if the result contains a Resize request.
isResizeResult ::  Maybe (WidgetResult s e) -> Bool
isResizeResult result = isJust resizeReq where
  requests = maybe Empty (^. L.requests) result
  resizeReq = Seq.findIndexL isResizeWidgets requests

-- | Checks if the result contains a ResizeImmediate request.
isResizeImmediateResult ::  Maybe (WidgetResult s e) -> Bool
isResizeImmediateResult result = isJust resizeReq where
  requests = maybe Empty (^. L.requests) result
  resizeReq = Seq.findIndexL isResizeWidgetsImmediate requests

-- | Checks if the result contains any kind of resize request.
isResizeAnyResult :: Maybe (WidgetResult s e) -> Bool
isResizeAnyResult res = isResizeResult res || isResizeImmediateResult res

-- | Checks if the platform is macOS
isMacOS :: WidgetEnv s e -> Bool
isMacOS wenv = _weOs wenv == "Mac OS X"

-- | Returns a string description of a node and its children.
widgetTreeDesc :: Int -> WidgetNode s e -> String
widgetTreeDesc level node = desc where
  desc = nodeDesc level node ++ "\n" ++ childDesc
  childDesc = foldMap (widgetTreeDesc (level + 1)) (_wnChildren node)

-- | Returns a string description of a node.
nodeDesc :: Int -> WidgetNode s e -> String
nodeDesc level node = infoDesc (_wnInfo node) where
  spaces = replicate (level * 2) ' '
  infoDesc info =
    spaces ++ "type: " ++ show (_wniWidgetType info) ++ "\n" ++
    spaces ++ "path: " ++ show (_wniPath info) ++ "\n" ++
    spaces ++ "vp: " ++ rectDesc (_wniViewport info) ++ "\n" ++
    spaces ++ "req: " ++ show (_wniSizeReqW info, _wniSizeReqH info) ++ "\n"
  rectDesc r = show (_rX r, _rY r, _rW r, _rH r)

-- | Returns a string description of a node info and its children.
widgetInstTreeDesc :: Int -> WidgetInstanceNode -> String
widgetInstTreeDesc level node = desc where
  desc = nodeInstDesc level node ++ "\n" ++ childDesc
  childDesc = foldMap (widgetInstTreeDesc (level + 1)) (_winChildren node)

-- | Returns a string description of a node info.
nodeInstDesc :: Int -> WidgetInstanceNode -> String
nodeInstDesc level node = infoDesc (_winInfo node) where
  spaces = replicate (level * 2) ' '
  infoDesc info =
    spaces ++ "type: " ++ show (_wniWidgetType info) ++ "\n" ++
    spaces ++ "path: " ++ show (_wniPath info) ++ "\n" ++
    spaces ++ "vp: " ++ rectDesc (_wniViewport info) ++ "\n" ++
    spaces ++ "req: " ++ show (_wniSizeReqW info, _wniSizeReqH info) ++ "\n"
  rectDesc r = show (_rX r, _rY r, _rW r, _rH r)

-- | Returns a string description of a node info and its children, from a node.
treeInstDescFromNode :: WidgetEnv s e -> Int -> WidgetNode s e -> String
treeInstDescFromNode wenv level node = widgetInstTreeDesc level nodeInst  where
  nodeInst = widgetGetInstanceTree (node ^. L.widget) wenv node
