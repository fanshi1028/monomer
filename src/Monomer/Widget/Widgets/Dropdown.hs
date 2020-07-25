{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}

module Monomer.Widget.Widgets.Dropdown (
  DropdownConfig(..),
  dropdown,
  dropdownConfig
) where

import Control.Applicative ((<|>))
import Control.Lens (ALens', (&), (^#), (#~))
import Control.Monad
import Data.Default
import Data.Foldable (find)
import Data.List (foldl')
import Data.Maybe (fromJust, fromMaybe, isJust)
import Data.Sequence (Seq(..), (<|), (|>))
import Data.Text (Text)
import Data.Traversable
import Data.Typeable (Typeable, cast)

import qualified Data.Map as M
import qualified Data.Sequence as Seq

import Monomer.Common.Geometry
import Monomer.Common.Style
import Monomer.Common.Tree
import Monomer.Event.Keyboard
import Monomer.Event.Types
import Monomer.Graphics.Color
import Monomer.Graphics.Drawing
import Monomer.Graphics.Renderer
import Monomer.Graphics.Types
import Monomer.Widget.BaseContainer
import Monomer.Widget.Types
import Monomer.Widget.Util
import Monomer.Widget.Widgets.ListView

data DropdownConfig s e a = DropdownConfig {
  _ddValue :: WidgetValue s a,
  _ddItems :: Seq a,
  _ddItemToText :: a -> Text,
  _ddOnChange :: [a -> e],
  _ddOnChangeReq :: [WidgetRequest s],
  _ddSelectedColor :: Color,
  _ddHighlightedColor :: Color,
  _ddHoverColor :: Color
}

newtype DropdownState = DropdownState {
  _isOpen :: Bool
}

newtype DropdownMessage = OnChangeMessage Int deriving Typeable

dropdownConfig :: WidgetValue s a -> Seq a -> (a -> Text) -> DropdownConfig s e a
dropdownConfig value items itemToText = DropdownConfig {
  _ddValue = value,
  _ddItems = items,
  _ddItemToText = itemToText,
  _ddOnChange = [],
  _ddOnChangeReq = [],
  _ddSelectedColor = gray,
  _ddHighlightedColor = darkGray,
  _ddHoverColor = lightGray
}

dropdown :: (Traversable t, Eq a) => ALens' s a -> t a -> (a -> Text) -> WidgetInstance s e
dropdown field items itemToText = dropdown_ config where
  config = dropdownConfig (WidgetLens field) newItems itemToText
  newItems = foldl' (|>) Empty items

dropdown_ :: (Eq a) => DropdownConfig s e a -> WidgetInstance s e
dropdown_ config = makeInstance (makeDropdown config newState) where
  newState = DropdownState False

makeInstance :: Widget s e -> WidgetInstance s e
makeInstance widget = (defaultWidgetInstance "dropdown" widget) {
  _instanceFocusable = True
}

makeDropdown :: (Eq a) => DropdownConfig s e a -> DropdownState -> Widget s e
makeDropdown config state = createContainer {
    _widgetInit = containerInit init,
    _widgetGetState = makeState state,
    _widgetMerge = containerMergeTrees merge,
    _widgetHandleEvent = containerHandleEvent handleEvent,
    _widgetHandleMessage = containerHandleMessage handleMessage,
    _widgetPreferredSize = containerPreferredSize preferredSize,
    _widgetResize = containerResize resize,
    _widgetRender = render
  }
  where
    isOpen = _isOpen state
    currentValue wenv = widgetValueGet (_weModel wenv) (_ddValue config)

    createDropdown wenv newState widgetInst = newInstance where
      selected = currentValue wenv
      path = _instancePath widgetInst
      newInstance = widgetInst {
        _instanceWidget = makeDropdown config newState,
        _instanceChildren = Seq.singleton $ makeListView config path selected
      }

    init wenv widgetInst = resultWidget $ createDropdown wenv state widgetInst

    merge wenv oldState newInstance = resultWidget $ createDropdown wenv newState newInstance where
      newState = fromMaybe state (useState oldState)

    handleEvent wenv target evt widgetInst = case evt of
      Click point _
        | openRequired point widgetInst -> Just $ handleOpenDropdown wenv widgetInst
        | closeRequired point widgetInst -> Just $ handleCloseDropdown wenv widgetInst
      KeyAction mode code status
        | isKeyDown code && not isOpen -> Just $ handleOpenDropdown wenv widgetInst
        | isKeyEsc code && isOpen -> Just $ handleCloseDropdown wenv widgetInst
      _
        | not isOpen -> Just $ resultReqs [IgnoreChildrenEvents] widgetInst
        | otherwise -> Nothing

    openRequired point widgetInst = not isOpen && inViewport where
      inViewport = pointInRect point (_instanceViewport widgetInst)

    closeRequired point widgetInst = isOpen && not inOverlay where
      inOverlay = case Seq.lookup 0 (_instanceChildren widgetInst) of
        Just inst -> pointInRect point (_instanceViewport inst)
        Nothing -> False

    handleOpenDropdown wenv widgetInst = resultReqs requests newInstance where
      selected = currentValue wenv
      selectedIdx = fromMaybe 0 (Seq.elemIndexL selected (_ddItems config))
      newState = DropdownState True
      newInstance = widgetInst {
        _instanceWidget = makeDropdown config newState
      }
      path = _instancePath widgetInst
      lvPath = firstChildPath widgetInst
      requests = [SetOverlay path, SetFocus lvPath]

    handleCloseDropdown wenv widgetInst = resultReqs requests newInstance where
      path = _instancePath widgetInst
      newState = DropdownState False
      newInstance = widgetInst {
        _instanceWidget = makeDropdown config newState
      }
      requests = [ResetOverlay, SetFocus path]

    handleMessage wenv target message widgetInst = cast message
      >>= \(OnChangeMessage idx) -> Seq.lookup idx (_ddItems config)
      >>= \value -> Just $ handleOnChange wenv idx value widgetInst

    handleOnChange wenv idx item widgetInst = WidgetResult (reqs <> newReqs) (events <> newEvents) newInstance where
      WidgetResult reqs events newInstance = handleCloseDropdown wenv widgetInst
      newReqs = Seq.fromList $ widgetValueSet (_ddValue config) item
      newEvents = Seq.fromList $ fmap ($ item) (_ddOnChange config)

    preferredSize wenv widgetInst children reqs = Node sizeReq reqs where
      Style{..} = _instanceStyle widgetInst
      size = getTextBounds wenv _styleText (dropdownLabel wenv)
      sizeReq = SizeReq size FlexibleSize StrictSize

    resize wenv viewport renderArea widgetInst children reqs = (widgetInst, assignedArea) where
      childrenReqs = Seq.zip children reqs
      area = case Seq.lookup 0 childrenReqs of
        Just (child, reqChild) -> (oViewport, oRenderArea) where
          reqHeight = _h . _sizeRequested . nodeValue $ reqChild
          maxHeight = min reqHeight 150
          oViewport = viewport { _ry = _ry viewport + _rh viewport, _rh = maxHeight }
          oRenderArea = renderArea { _ry = _ry renderArea + _rh viewport }
        Nothing -> (viewport, renderArea)
      assignedArea = Seq.singleton area

    render renderer wenv WidgetInstance{..} =
      do
        drawStyledBackground renderer _instanceRenderArea _instanceStyle
        drawStyledText_ renderer _instanceRenderArea _instanceStyle (dropdownLabel wenv)

        when (isOpen && isJust listViewOverlay) $
          createOverlay renderer $ renderOverlay renderer wenv (fromJust listViewOverlay)
      where
        listViewOverlay = Seq.lookup 0 _instanceChildren

    renderOverlay renderer wenv overlayInstance = renderAction where
      renderAction = _widgetRender (_instanceWidget overlayInstance) renderer wenv overlayInstance

    dropdownLabel wenv = _ddItemToText config $ currentValue wenv

makeListView :: (Eq a) => DropdownConfig s e a -> Path -> a -> WidgetInstance s e
makeListView DropdownConfig{..} dropdownPath selected = listView_ lvConfig where
  lvConfig = ListViewConfig {
    _lvValue = WidgetValue selected,
    _lvItems = _ddItems,
    _lvItemToText = _ddItemToText,
    _lvOnChange = [],
    _lvOnChangeReq = [SendMessage dropdownPath . OnChangeMessage],
    _lvSelectedColor = _ddSelectedColor,
    _lvHighlightedColor = _ddHighlightedColor,
    _lvHoverColor = _ddHoverColor
  }
