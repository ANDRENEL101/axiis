///////////////////////////////////////////////////////////////////////////////
//	Copyright (c) 2009 Team Axiis
//
//	Permission is hereby granted, free of charge, to any person
//	obtaining a copy of this software and associated documentation
//	files (the "Software"), to deal in the Software without
//	restriction, including without limitation the rights to use,
//	copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following
//	conditions:
//
//	The above copyright notice and this permission notice shall be
//	included in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//	OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////

package org.axiis
{
	import com.degrafa.IGeometryComposition;
	
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	
	import mx.core.IFactory;
	import mx.core.IToolTip;
	import mx.core.UIComponent;
	import mx.managers.ToolTipManager;
	
	import org.axiis.core.AxiisSprite;
	import org.axiis.core.ILayout;
	
	/**
	 * DataCanvas manages the placement and the rendering of layouts.
	 */
	public class DataCanvas extends UIComponent
	{
		[Bindable]
		/**
		 * A placeholder for fills. Modifying this property has no
		 * effect on the rendering of the DataCanvas.
		 */
		public var fills:Array = [];
		
		[Bindable]
		/**
		 * A placeholder for strokes. Modifying this property has no
		 * effect on the rendering of the DataCanvas.
		 */
		public var strokes:Array = [];
		
		[Bindable]
		/**
		 * A placeholder for palettes. Modifying this property has no
		 * effect on the rendering of the DataCanvas.
		 */
		public var palettes:Array = [];
		
		/**
		 * Constructor.
		 */
		public function DataCanvas()
		{
			super();
		}
		
		//TODO Do we need this on the DataCanvas level
		/**
		 * @private
		 */
		public var labelFunction:Function;
		
		//TODO Do we need this on the DataCanvas level
		/**
		 * @private
		 */
		public var dataFunction:Function;
		
		/**
		 * Whether or not data tips should be shown when rolling the mouse over
		 * items in the DataCanvas's layouts
		 */
		public var showDataTips:Boolean = true;
		
		// TODO This is currently unused
		/**
		 * @private
		 */
		public var toolTipClass:IFactory;
		
		/**
		 * @private
		 */
		public var hitRadius:Number = 1;
		
		private var toolTips:Array = [];
		
		// TODO This isn't doing anything.  We should cut it.
		[Bindable(event="dataProviderChange")]
		/**
		 * A placeholder for data used by layouts managed by this DataCanvas.
		 * Setting this value re-renders the layouts.
		 */
		public function get dataProvider():Object
		{
			return _dataProvider;
		}
		public function set dataProvider(value:Object):void
		{
			if(value != _dataProvider)
			{
				_dataProvider = value;
				invalidateDisplayList();
				dispatchEvent(new Event("dataProviderChange"));
			}
		}
		private var _dataProvider:Object;
		
		/**
		 * An Array of ILayouts that this DataCanvas should render. Layouts
		 * appearing later in the array will render on top of earlier layouts.
		 */
		public var layouts:Array;
		
		/**
		 * An array of geometries that should be rendered behind the layouts.
		 */
		public var backgroundGeometries:Array;
		
		/**
		 * An array of geometries that should be rendered in front of the
		 * layouts.
		 */
		public var foregroundGeometries:Array;
		
		private var invalidatedLayouts:Array = [];
		
		private var _backgroundSprites:Array = [];
		
		private var _foregroundSprites:Array = [];
		
		private var _background:AxiisSprite;
		
		private var _foreground:AxiisSprite;
		
		/**
		 * @private
		 */
		override protected function createChildren():void
		{
			super.createChildren();
			
			_background=new AxiisSprite();
			addChild(_background);

			for each(var layout:ILayout in layouts)
			{
				layout.registerOwner(this);
				var sprite:Sprite = layout.getSprite(this);
				addChild(sprite);
				
				layout.addEventListener("layoutInvalidate",handleLayoutInvalidate);
				if (layout.emitDataTips)
					sprite.addEventListener(MouseEvent.MOUSE_OVER,onItemMouseOver);
				sprite.addEventListener(MouseEvent.CLICK,onItemMouseClick);
				sprite.addEventListener(MouseEvent.DOUBLE_CLICK,onItemMouseDoubleClick);
				sprite.addEventListener(MouseEvent.MOUSE_OUT,onItemMouseOut);
				sprite.addEventListener(MouseEvent.MOUSE_DOWN,onItemMouseDown);
				sprite.addEventListener(MouseEvent.MOUSE_UP,onItemMouseUp);
		
				invalidatedLayouts.push(layout);
			}
			
			_foreground=new AxiisSprite();
			addChild(_foreground);
		}
		
		/**
		 * @private
		 */
		override protected function commitProperties():void
		{
			super.commitProperties();
			var s:AxiisSprite;
			var i:int;
			if (backgroundGeometries && _backgroundSprites.length < backgroundGeometries.length) {
				for (i = _backgroundSprites.length-1; i<backgroundGeometries.length; i++) {
					s=new AxiisSprite();
					_backgroundSprites.push(s);
					_background.addChild(s);
				}
			}
			
			if (foregroundGeometries && _foregroundSprites.length < foregroundGeometries.length ) {
				for (i=_foregroundSprites.length-1; i<foregroundGeometries.length; i++) {
					s=new AxiisSprite();
					_foregroundSprites.push(s);
					_foreground.addChild(s);
				}
			}
		}
		
		// TODO implement measure. We should use defaults of 0,0 until we can figure out how to measure things
		/**
		 * @private
		 */
		override protected function measure():void
		{
			super.measure();
			measuredWidth = 400;
			measuredHeight = 400;
		}
		
		private var _invalidated:Boolean=false;
		
		/**
		 * @private
		 */
		override public function invalidateDisplayList():void
		{
			if (!_invalidated)
				invalidateAllLayouts();
			
			_invalidated = true;
		} 
		
		/**
		 * @private
		 */
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth,unscaledHeight);
			
			_background.graphics.clear();
			
			var i:int=0;
			for each (var bg:Object in backgroundGeometries) {
				_backgroundSprites[i].graphics.clear();
				if (bg is ILayout) {
					ILayout(bg).render(_backgroundSprites[i])
				}
				else if (bg is IGeometryComposition) {
					bg.preDraw();
					bg.draw(_backgroundSprites[i].graphics,bg.bounds);
				}
				i++;
			}
			
			while(invalidatedLayouts.length > 0)
			{
				var layout:ILayout = ILayout(invalidatedLayouts.pop());				
				layout.render();
			}
			
			i=0;
			_foreground.graphics.clear();
			for each (var fg:Object in foregroundGeometries) {
				_foregroundSprites[i].graphics.clear();
				if (fg is ILayout) {
					ILayout(fg).render(_foregroundSprites[i])
				}
				else if (fg is IGeometryComposition) {
					fg.preDraw();
					fg.draw(_foregroundSprites[i].graphics,fg.bounds);
				}
				i++;
			}
			
			
			/* this.graphics.clear();
			this.graphics.beginFill(0xff,.1);
			this.graphics.drawRect(0,0,width,height);
			this.graphics.endFill(); */
			
			_invalidated = false;
		}
		
		/**
		 * Handler for when a layout's layoutInvalidated event has been caught.
		 * Invalidates the display list so the layout can be re-rendered. 
		 */
		protected function handleLayoutInvalidate(event:Event):void
		{
			var layout:ILayout = event.target as ILayout;
			if(invalidatedLayouts.indexOf(layout) == -1)
			{
				invalidatedLayouts.push(layout);
				super.invalidateDisplayList();
			}
		}
		
		/**
		 * Invalidates all layouts that this DataCanvas managers. 
		 */
		protected function invalidateAllLayouts():void
		{
			for each(var layout:ILayout in layouts)
			{
				invalidatedLayouts.push(layout);
			}
			super.invalidateDisplayList();
		}
		
		// TODO This should be private
		/**
		 * @private
		 */
		public function onItemMouseOver(e:MouseEvent):void
		{
			var axiisSprite:AxiisSprite = e.target as AxiisSprite;
			if(!axiisSprite)
				return;
			
			if(axiisSprite.layout)
			{
				if(showDataTips && axiisSprite.layout.dataTipLabelFunction != null)
				{
					var hitSiblings:Array = getHitSiblings(axiisSprite);
					for each(var sibling:AxiisSprite in hitSiblings)
					{
						showToolTip(sibling);
					}
					if(doToolTipsOverlap())
						repositionToolTips();
				}
			}
		}
		
		/**
		 * @private
		 */
		public function onItemMouseOut(e:MouseEvent):void
		{
			var axiisSprite:AxiisSprite = e.target as AxiisSprite;
			if(!axiisSprite)
				return;
			
			while(toolTips.length > 0)
			{
				var tt:IToolTip = IToolTip(toolTips.pop());
				ToolTipManager.destroyToolTip(tt);
				tt = null;
			}	
		}
		
		/**
		 * @private
		 */
		public function onItemMouseDown(e:MouseEvent):void {
		}
		
		/**
		 * @private
		 */
		public function onItemMouseUp(e:MouseEvent):void {
		}
		
		/**
		 * @private
		 */
		public function onItemMouseClick(e:MouseEvent):void {
		}
		
		/**
		 * @private
		 */
		public function onItemMouseDoubleClick(e:MouseEvent):void {
		}
		
		private function getHitSiblings(axiisSprite:AxiisSprite):Array
		{
			var s:Sprite = new Sprite();
			s.graphics.clear();
			s.graphics.beginFill(0,0);
			s.graphics.drawCircle(mouseX,mouseY,hitRadius);
			s.graphics.endFill();
			addChild(s);
			
			var toReturn:Array = [];
			toReturn.push(axiisSprite);
			
			/*var siblings:Array = axiisSprite.layout.childSprites;
			for each(var sibling:AxiisSprite in siblings)
			{
				if(sibling.hitTestObject(s))
				{
					toReturn.push(sibling);
				}
			}*/
			
			removeChild(s);
			
			return toReturn;
		}
		
		private function showToolTip(axiisSprite:AxiisSprite):void
		{
			var text:String = axiisSprite.layout.dataTipLabelFunction.call(this,axiisSprite.data);
			if(text != null && text != "")
			{
				var tt:IToolTip = ToolTipManager.createToolTip(text,stage.mouseX + 10,stage.mouseY + 10);
				if(axiisSprite.layout.dataTipPositionFunction != null)
				{
					var position:Point = axiisSprite.layout.dataTipPositionFunction.call(this,axiisSprite,tt);
					tt.x = position.x;
					tt.y = position.y;
				}
				toolTips.push(tt);
			}
		}
		
		/**
		 * Reposition the tool tips by laying them out in four columns around the cursor.
		 * The first column starts down and to the right of the cursor, the second
		 * starts down and to the left, the third is above and to the left, and the
		 * last column starts above and to the right. Each column grows vertically
		 * away from the cursor.
		 * 
		 * This method needs to be adjusted to account for tool tips that end up offscreen.
		 */
		private function repositionToolTips():void
		{
			var startX:Number = stage.mouseX;
			var startY:Number = stage.mouseY;
			var gapX:Number = 10;
			var gapY:Number = 10;
			var offsetYs:Array = [0,0,0,0];
			for(var a:int = 0; a < toolTips.length; a++)
			{
				var tt:IToolTip = toolTips[a] as IToolTip;
				var offsetY:Number = offsetYs[a % 4];
				if(a % 4 == 0)
				{
					tt.x = startX + gapX;
					tt.y = startY + gapY + offsetY;
				}
				else if(a % 4 == 1)
				{
					tt.x = startX - gapX - tt.width;
					tt.y = startY + gapY + offsetY;
				}
				else if(a % 4 == 2)
				{
					tt.x = startX - gapX - tt.width;
					tt.y = startY - gapY - tt.height - offsetY;
				}
				else
				{
					tt.x = startX + gapX;
					tt.y = startY - gapY - tt.height - offsetY;
				}
				offsetYs[a % 4] += tt.height;
			}
		}
		
		private function doToolTipsOverlap():Boolean 	
		{
			if(toolTips.length < 1)
				return false;
				
			var toolTipsOverlap:Boolean = false;
			for(var a:int = 0; a < toolTips.length - 1; a++)
			{
				var toolTip1:IToolTip = toolTips[a];
				for(var b:int = a + 1; b < toolTips.length; b++)
				{
					var toolTip2:IToolTip = toolTips[b];
					if(toolTip1.hitTestObject(toolTip2 as DisplayObject))
						return true;
				}
			}
			return false;
		}
	}
}