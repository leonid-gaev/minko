package aerys.minko.render.renderer
{
	import aerys.minko.Minko;
	import aerys.minko.ns.minko;
	import aerys.minko.ns.minko_render;
	import aerys.minko.render.Viewport;
	import aerys.minko.type.Factory;
	import aerys.minko.type.log.DebugLevel;
	import aerys.minko.type.stream.IndexStream;
	
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.IndexBuffer3D;
	import flash.utils.getTimer;
	
	public class DefaultRenderer implements IRenderer
	{
		use namespace minko;
		use namespace minko_render;
	
		private static const SORT	: Boolean					= true;
		
		private var _context		: Context3D					= null;
		private var _currentState	: RendererState				= null;
		private var _numTriangles	: uint						= 0;
		private var _viewport		: Viewport					= null;
		private var _drawingTime	: int						= 0;
		private var _frame			: uint						= 0;
	
		private var _states			: Vector.<RendererState>	= new Vector.<RendererState>();
		private var _numStates		: int						= 0;
		
		public function get numTriangles()	: uint			{ return _numTriangles; }
		public function get viewport()		: Viewport		{ return _viewport; }
		public function get drawingTime()	: int			{ return _drawingTime; }
		public function get frameId()		: uint			{ return _frame; }
		
		public function DefaultRenderer(viewport : Viewport, context : Context3D)
		{
			_viewport = viewport;
			_context = context;
			
			_context.enableErrorChecking = (Minko.debugLevel & DebugLevel.RENDERER) != 0;
		}
		
		public function pushState(state : RendererState) : void
		{
			_states[int(_numStates++)] = state;
			_currentState = state;
		}
		
		public function drawTriangles(offset : uint = 0, numTriangles : int = -1) : void
		{
			_currentState.offsets.push(offset);
			_currentState.numTriangles.push(numTriangles);
		}
		
		public function clear(red		: Number	= 0.,
							  green		: Number	= 0.,
							  blue		: Number	= 0.,
							  alpha		: Number	= 1.,
							  depth		: Number	= 1.,
							  stencil	: uint		= 0,
							  mask		: uint		= 0xffffffff)  :void
		{
			_numTriangles = 0;
			_drawingTime = 0;
			
			_currentState = null;
			_numStates = 0;
		}
		
		public function drawToBackBuffer() : void
		{
			var time : int = getTimer();
			
			if (SORT && _numStates > 1)
				RendererState.sort(_states, _numStates);
			
			var actualState : RendererState = null;
			
			for (var i : int = 0; i < _numStates; ++i)
			{
				var state			: RendererState = _states[i];
				var offsets 		: Vector.<uint>	= state.offsets;
				var numTriangles 	: Vector.<int> 	= state.numTriangles;
				var numCalls 		: int 			= offsets.length;
				
				if (actualState)
					state.prepareContextDelta(_context, actualState);
				else
					state.prepareContext(_context);
				
				for (var j : int = 0; j < numCalls; ++j)
				{
					var iStream : IndexStream	= state.indexStream;
					var iBuffer : IndexBuffer3D = iStream.resource.getIndexBuffer3D(_context);
					var count	: int			= numTriangles[j];
					
					_numTriangles += count == -1
									 ? iStream.length / 3.
									 : count;
					
					_context.drawTriangles(iBuffer, offsets[j], count);
				}
				
				actualState = state;
			}
			
			_drawingTime += getTimer() - time;
		}
		
		public function present() : void
		{
			var time : int = getTimer();
			
			if (_numStates != 0)
				_context.present();
			
			_drawingTime += getTimer() - time;
			++_frame;
		}
		
		public function dumpBackbuffer(bitmapData : BitmapData) : void
		{
			var time : int = getTimer();
			
			if (_numStates != 0)
				_context.drawToBitmapData(bitmapData);
			
			_drawingTime += getTimer() - time;
			++_frame;
		}
	}
}