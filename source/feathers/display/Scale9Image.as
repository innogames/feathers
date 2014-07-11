/*
Feathers
Copyright 2012-2014 Joshua Tynjala. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.display
{
	import feathers.core.IValidating;
	import feathers.core.ValidationQueue;
	import feathers.textures.Scale9Textures;
	import feathers.utils.display.getDisplayObjectDepthFromStage;

	import flash.errors.IllegalOperationError;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.QuadBatch;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	import starling.utils.MatrixUtil;

	[Exclude(name="numChildren",kind="property")]
	[Exclude(name="isFlattened",kind="property")]
	[Exclude(name="addChild",kind="method")]
	[Exclude(name="addChildAt",kind="method")]
	[Exclude(name="broadcastEvent",kind="method")]
	[Exclude(name="broadcastEventWith",kind="method")]
	[Exclude(name="contains",kind="method")]
	[Exclude(name="getChildAt",kind="method")]
	[Exclude(name="getChildByName",kind="method")]
	[Exclude(name="getChildIndex",kind="method")]
	[Exclude(name="removeChild",kind="method")]
	[Exclude(name="removeChildAt",kind="method")]
	[Exclude(name="removeChildren",kind="method")]
	[Exclude(name="setChildIndex",kind="method")]
	[Exclude(name="sortChildren",kind="method")]
	[Exclude(name="swapChildren",kind="method")]
	[Exclude(name="swapChildrenAt",kind="method")]
	[Exclude(name="flatten",kind="method")]
	[Exclude(name="unflatten",kind="method")]

	/**
	 * Scales an image with nine regions to maintain the aspect ratio of the
	 * corners regions. The top and bottom regions stretch horizontally, and the
	 * left and right regions scale vertically. The center region stretches in
	 * both directions to fill the remaining space.
	 */
	public class Scale9Image extends Sprite implements IValidating
	{
		/**
		 * @private
		 */
		private static const HELPER_MATRIX:Matrix = new Matrix();

		/**
		 * @private
		 */
		private static const HELPER_POINT:Point = new Point();

		/**
		 * @private
		 */
		private static var helperImage:Image;

		/**
		 * Constructor.
		 */
		public function Scale9Image(textures:Scale9Textures, textureScale:Number = 1)
		{
			super();
			this.textures = textures;
			this._textureScale = textureScale;
			this._hitArea = new Rectangle();
			this.readjustSize();

			this._batch = new QuadBatch();
			this._batch.touchable = false;
			this.addChild(this._batch);

			this.addEventListener(Event.FLATTEN, flattenHandler);
			this.addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		/**
		 * @private
		 */
		private var _propertiesChanged:Boolean = true;

		/**
		 * @private
		 */
		private var _layoutChanged:Boolean = true;

		/**
		 * @private
		 */
		private var _renderingChanged:Boolean = true;

		/**
		 * @private
		 */
		private var _frame:Rectangle;

		/**
		 * @private
		 */
		private var _textures:Scale9Textures;

		/**
		 * The textures displayed by this image.
		 *
		 * <p>In the following example, the textures are changed:</p>
		 *
		 * <listing version="3.0">
		 * image.textures = new Scale9Textures( texture, scale9Grid );</listing>
		 */
		public function get textures():Scale9Textures
		{
			return this._textures;
		}

		/**
		 * @private
		 */
		public function set textures(value:Scale9Textures):void
		{
			if(!value)
			{
				throw new IllegalOperationError("Scale9Image textures cannot be null.");
			}
			if(this._textures == value)
			{
				return;
			}
			this._textures = value;
			var texture:Texture = this._textures.texture;
			this._frame = texture.frame;
			if(!this._frame)
			{
				this._frame = new Rectangle(0, 0, texture.width, texture.height);
			}
			this._layoutChanged = true;
			this._renderingChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _width:Number = NaN;

		/**
		 * @private
		 */
		override public function get width():Number
		{
			return this._width;
		}

		/**
		 * @private
		 */
		override public function set width(value:Number):void
		{
			if(this._width == value)
			{
				return;
			}
			this._width = this._hitArea.width = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _height:Number = NaN;

		/**
		 * @private
		 */
		override public function get height():Number
		{
			return this._height;
		}

		/**
		 * @private
		 */
		override public function set height(value:Number):void
		{
			if(this._height == value)
			{
				return;
			}
			this._height = this._hitArea.height = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _textureScale:Number = 1;

		/**
		 * The amount to scale the texture. Useful for DPI changes.
		 *
		 * <p>In the following example, the texture scale is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.textureScale = 2;</listing>
		 *
		 * @default 1
		 */
		public function get textureScale():Number
		{
			return this._textureScale;
		}

		/**
		 * @private
		 */
		public function set textureScale(value:Number):void
		{
			if(this._textureScale == value)
			{
				return;
			}
			this._textureScale = value;
			this._layoutChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _smoothing:String = TextureSmoothing.BILINEAR;

		/**
		 * The smoothing value to pass to the images.
		 *
		 * <p>In the following example, the smoothing is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.smoothing = TextureSmoothing.NONE;</listing>
		 *
		 * @default starling.textures.TextureSmoothing.BILINEAR
		 *
		 * @see starling.textures.TextureSmoothing
		 */
		public function get smoothing():String
		{
			return this._smoothing;
		}

		/**
		 * @private
		 */
		public function set smoothing(value:String):void
		{
			if(this._smoothing == value)
			{
				return;
			}
			this._smoothing = value;
			this._propertiesChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _color:uint = 0xffffff;

		/**
		 * The color value to pass to the images.
		 *
		 * <p>In the following example, the color is changed:</p>
		 *
		 * <listing version="3.0">
		 * image.color = 0xff00ff;</listing>
		 *
		 * @default 0xffffff
		 */
		public function get color():uint
		{
			return this._color;
		}

		/**
		 * @private
		 */
		public function set color(value:uint):void
		{
			if(this._color == value)
			{
				return;
			}
			this._color = value;
			this._propertiesChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _useSeparateBatch:Boolean = true;

		/**
		 * Determines if the regions are batched normally by Starling or if
		 * they're batched separately.
		 *
		 * <p>In the following example, the separate batching is disabled:</p>
		 *
		 * <listing version="3.0">
		 * image.useSeparateBatch = false;</listing>
		 *
		 * @default true
		 */
		public function get useSeparateBatch():Boolean
		{
			return this._useSeparateBatch;
		}

		/**
		 * @private
		 */
		public function set useSeparateBatch(value:Boolean):void
		{
			if(this._useSeparateBatch == value)
			{
				return;
			}
			this._useSeparateBatch = value;
			this._renderingChanged = true;
			this.invalidate();
		}

		/**
		 * Defines if the center parts of the image should be tiled or if they should be stretched.
		 *
		 * When set to true the parts in the middle sections are filled with as many tiles as possible and then
		 * all the tiles are stretched so that the remaining gap is filled. This guarantees that the edges fit
		 * perfectly to the border parts.
		 *
		 * @default false
		 */
		public function get isTiled():Boolean
		{
			return _isTiled;
		}

		public function set isTiled(value:Boolean):void
		{
			_isTiled = value;
			this._renderingChanged = true;
			this.invalidate();
		}

		/**
		 * @private
		 */
		private var _hitArea:Rectangle;

		/**
		 * @private
		 */
		private var _batch:QuadBatch;

		/**
		 * @private
		 */
		private var _isValidating:Boolean = false;

		/**
		 * @private
		 */
		private var _isInvalid:Boolean = false;

		/**
		 * @private
		 */
		private var _validationQueue:ValidationQueue;

		/**
		 * @private
		 */
		private var _depth:int = -1;

		/**
		 * @private
		 */
		private var _isTiled:Boolean = false;

		/**
		 * @copy feathers.core.IValidating#depth
		 */
		public function get depth():int
		{
			return this._depth;
		}

		/**
		 * @private
		 */
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if(!resultRect)
			{
				resultRect = new Rectangle();
			}

			var minX:Number = Number.MAX_VALUE, maxX:Number = -Number.MAX_VALUE;
			var minY:Number = Number.MAX_VALUE, maxY:Number = -Number.MAX_VALUE;

			if (targetSpace == this) // optimization
			{
				minX = this._hitArea.x;
				minY = this._hitArea.y;
				maxX = this._hitArea.x + this._hitArea.width;
				maxY = this._hitArea.y + this._hitArea.height;
			}
			else
			{
				this.getTransformationMatrix(targetSpace, HELPER_MATRIX);

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x, this._hitArea.y, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x, this._hitArea.y + this._hitArea.height, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x + this._hitArea.width, this._hitArea.y, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this._hitArea.x + this._hitArea.width, this._hitArea.y + this._hitArea.height, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;
			}

			resultRect.x = minX;
			resultRect.y = minY;
			resultRect.width  = maxX - minX;
			resultRect.height = maxY - minY;

			return resultRect;
		}

		/**
		 * @private
		 */
		override public function hitTest(localPoint:Point, forTouch:Boolean=false):DisplayObject
		{
			if(forTouch && (!this.visible || !this.touchable))
			{
				return null;
			}
			return this._hitArea.containsPoint(localPoint) ? this : null;
		}

		/**
		 * @private
		 */
		override public function flatten():void
		{
			this.validate();
			super.flatten();
		}

		/**
		 * @copy feathers.core.IValidating#validate()
		 */
		public function validate():void
		{
			if(!this._validationQueue || !this.stage || !this._isInvalid)
			{
				return;
			}
			if(this._isValidating)
			{
				//we were already validating, and something else told us to
				//validate. that's bad.
				this._validationQueue.addControl(this, true);
				return;
			}
			this._isValidating = true;
			if(this._propertiesChanged || this._layoutChanged || this._renderingChanged)
			{
				this._batch.batchable = !this._useSeparateBatch;
				this._batch.reset();

				if(!helperImage)
				{
					//because Scale9Textures enforces it, we know for sure that
					//this texture will have a size greater than zero, so there
					//won't be an error from Quad.
					helperImage = new Image(this._textures.middleCenter);
				}
				helperImage.smoothing = this._smoothing;
				helperImage.color = this._color;

				const grid:Rectangle = this._textures.scale9Grid;
				var scaledLeftWidth:Number = grid.x * this._textureScale;
				var scaledTopHeight:Number = grid.y * this._textureScale;
				var scaledRightWidth:Number = (this._frame.width - grid.x - grid.width) * this._textureScale;
				var scaledBottomHeight:Number = (this._frame.height - grid.y - grid.height) * this._textureScale;
				const scaledCenterWidth:Number = this._width - scaledLeftWidth - scaledRightWidth;
				const scaledMiddleHeight:Number = this._height - scaledTopHeight - scaledBottomHeight;
				if(scaledCenterWidth < 0)
				{
					var offset:Number = scaledCenterWidth / 2;
					scaledLeftWidth += offset;
					scaledRightWidth += offset;
				}
				if(scaledMiddleHeight < 0)
				{
					offset = scaledMiddleHeight / 2;
					scaledTopHeight += offset;
					scaledBottomHeight += offset;
				}

				if(scaledTopHeight > 0)
				{
					if(scaledLeftWidth > 0)
					{
						addPart(this._textures.topLeft, 0, 0, scaledLeftWidth, scaledTopHeight);
					}

					if(scaledCenterWidth > 0)
					{
						addPart(_textures.topCenter, scaledLeftWidth, 0, scaledCenterWidth, scaledTopHeight);
					}

					if(scaledRightWidth > 0)
					{
						addPart(this._textures.topRight, this._width - scaledRightWidth, 0, scaledRightWidth, scaledTopHeight);
					}
				}

				if(scaledMiddleHeight > 0)
				{
					if(scaledLeftWidth > 0)
					{
						addPart(this._textures.middleLeft, 0, scaledTopHeight, scaledLeftWidth, scaledMiddleHeight);
					}

					if(scaledCenterWidth > 0)
					{
						addPart(this._textures.middleCenter, scaledLeftWidth, scaledTopHeight, scaledCenterWidth, scaledMiddleHeight);
					}

					if(scaledRightWidth > 0)
					{
						addPart(this._textures.middleRight, this._width - scaledRightWidth, scaledTopHeight, scaledRightWidth, scaledMiddleHeight);
					}
				}

				if(scaledBottomHeight > 0)
				{
					if(scaledLeftWidth > 0)
					{
						addPart(this._textures.bottomLeft, 0, this._height - scaledBottomHeight, scaledLeftWidth, scaledBottomHeight);
					}

					if(scaledCenterWidth > 0)
					{
						addPart(this._textures.bottomCenter, scaledLeftWidth, this._height - scaledBottomHeight, scaledCenterWidth, scaledBottomHeight);
					}

					if(scaledRightWidth > 0)
					{
						addPart(this._textures.bottomRight, this._width - scaledRightWidth, this._height - scaledBottomHeight, scaledRightWidth, scaledBottomHeight);
					}
				}
			}

			this._propertiesChanged = false;
			this._layoutChanged = false;
			this._renderingChanged = false;
			this._isInvalid = false;
			this._isValidating = false;
		}

		/**
		 * Fills a target space with a texture by either just scaling the texture or tiling and scaling it.
		 *
		 * When isTiled is true, the texture is tiled as many times as possible and every single tile is stretched so
		 * that the sum of all tiles matches the requested width & height.
		 * When isTiled is false or the requested width & height is smaller than 2 tiles the texture is just scaled
		 * without any tiling.
		 *
		 * @param texture The texture to add.
		 * @param x The x coordinate of the target space.
		 * @param y The y coordinate of the target space.
		 * @param width The width of the target space.
		 * @param height The height of the target space.
		 */
		protected function addPart(texture:Texture, x:Number, y:Number, width:Number, height:Number):void
		{
			helperImage.texture = texture;
			helperImage.readjustSize();

			var numberOfColumns: int = 1;
			var numberOfRows: int = 1;

			if (_isTiled) {
				// Scale the tile size according to the textureScale
				var originalTileWidth:Number = texture.width * this._textureScale;
				var originalTileHeight:Number = texture.height * this._textureScale;

				// Calculate how many tiles fit into the target space
				if (width > originalTileWidth) {
					numberOfColumns = width / originalTileWidth;
				}
				if (height > originalTileHeight) {
					numberOfRows = height / originalTileHeight;
				}
			}

			// Scale the tile size according to the number of tiles and the target space
			var tileWidth:Number = width / numberOfColumns;
			var tileHeight:Number = height / numberOfRows;

			var currentX:Number = x;
			var currentY:Number = y;

			helperImage.width = tileWidth;
			helperImage.height = tileHeight;

			// Fill the area with the tiles
			for (var i: int = 0; i < numberOfRows; i++) {
				helperImage.y = currentY;

				for (var j: int = 0; j < numberOfColumns; j++) {
					helperImage.x = currentX;
					this._batch.addImage(helperImage);

					currentX += tileWidth;
				}

				currentX = x;
				currentY += tileHeight;
			}
		}

		/**
		 * Readjusts the dimensions of the image according to its current
		 * textures. Call this method to synchronize image and texture size
		 * after assigning textures with a different size.
		 */
		public function readjustSize():void
		{
			this.width = this._frame.width * this._textureScale;
			this.height = this._frame.height * this._textureScale;
		}

		/**
		 * @private
		 */
		protected function invalidate():void
		{
			if(this._isInvalid)
			{
				return;
			}
			this._isInvalid = true;
			if(!this._validationQueue)
			{
				return;
			}
			this._validationQueue.addControl(this, false);
		}

		/**
		 * @private
		 */
		private function flattenHandler(event:Event):void
		{
			this.validate();
		}

		/**
		 * @private
		 */
		private function addedToStageHandler(event:Event):void
		{
			this._depth = getDisplayObjectDepthFromStage(this);
			this._validationQueue = ValidationQueue.forStarling(Starling.current);
			if(this._isInvalid)
			{
				this._validationQueue.addControl(this, false);
			}
		}
	}
}