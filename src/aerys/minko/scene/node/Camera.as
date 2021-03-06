package aerys.minko.scene.node
{
	import aerys.minko.scene.controller.camera.CameraController;
	import aerys.minko.scene.data.CameraDataProvider;
	import aerys.minko.type.Signal;
	import aerys.minko.type.binding.DataBindings;
	import aerys.minko.type.math.Matrix4x4;
	import aerys.minko.type.math.Ray;

	public class Camera extends AbstractSceneNode
	{
		public static const DEFAULT_FOV		: Number	= Math.PI * .25;
		public static const DEFAULT_ZNEAR	: Number	= .1;
		public static const DEFAULT_ZFAR	: Number	= 500.;

		private var _cameraData		: CameraDataProvider	= null;
		
		private var _enabled		: Boolean				= true;
		
		private var _activated		: Signal				= new Signal('Camera.activated');
		private var _deactivated	: Signal				= new Signal('Camera.deactivated');

		public function get cameraData() : CameraDataProvider
		{
			return _cameraData;
		}
		
		public function get fieldOfView() : Number
		{
			return _cameraData.fieldOfView;
		}
		public function set fieldOfView(value : Number) : void
		{
			_cameraData.fieldOfView = value;
		}
		
		public function get zNear() : Number
		{
			return _cameraData.zNear;
		}
		public function set zNear(value : Number) : void
		{
			_cameraData.zNear = value;
		}
		
		public function get zFar() : Number
		{
			return _cameraData.zFar;
		}
		public function set zFar(value : Number) : void
		{
			_cameraData.zFar = value;
		}
		
		public function get enabled() : Boolean
		{
			return _enabled;
		}
		public function set enabled(value : Boolean) : void
		{
			if (value != _enabled)
			{
				_enabled = value;
				
				if (_enabled)
					_activated.execute(this);
				else
					_deactivated.execute(this);
			}
		}
		
		public function get activated() : Signal
		{
			return _activated;
		}
		public function get deactivated() : Signal
		{
			return _deactivated;
		}
		
		public function get worldToView() : Matrix4x4
		{
			return localToWorld;
		}
		
		public function get viewToWorld() : Matrix4x4
		{
			return worldToLocal;
		}
		
		public function Camera(fieldOfView	: Number = DEFAULT_FOV,
							   zNear		: Number = DEFAULT_ZNEAR,
							   zFar			: Number = DEFAULT_ZFAR)
		{
			super();
			
			initialize(fieldOfView, zNear, zFar);
		}
		
		private function initialize(fieldOfView	: Number,
									zNear		: Number,
									zFar		: Number) : void
		{
			_cameraData = new CameraDataProvider(worldToLocal, localToWorld);
			_cameraData.fieldOfView = fieldOfView;
			_cameraData.zNear = zNear;
			_cameraData.zFar = zFar;
			
			addController(new CameraController());
		}
		
		public function unproject(x : Number, y : Number, out : Ray = null) : Ray
		{
			if (!(root is Scene))
				throw new Error('Camera must be in the scene to unproject vectors.');
			
			out ||= new Ray();
			
			var sceneBindings	: DataBindings	= (root as Scene).bindings;
			var zNear			: Number		= _cameraData.zNear;
			var zFar			: Number		= _cameraData.zFar;
			var fovDiv2			: Number		= _cameraData.fieldOfView * 0.5;
			var width			: Number		= sceneBindings.getProperty('viewportWidth');
			var height			: Number		= sceneBindings.getProperty('viewportHeight');
			var xPercent		: Number		= 2.0 * (x / width - 0.5);
			var yPercent 		: Number		= 2.0 * (y / height - 0.5);
			var dx				: Number 		= Math.tan(fovDiv2) * xPercent * (width / height);
			var dy				: Number 		= -Math.tan(fovDiv2) * yPercent;
			
			out.origin.set(dx * zNear, dy * zNear, zNear);
			out.direction.set(dx * zNear, dy * zNear, zNear).normalize();
			
			localToWorld.transformVector(out.origin, out.origin);
			localToWorld.deltaTransformVector(out.direction, out.direction);
			
			return out;
		}
		
		public function getWorldToScreen(output : Matrix4x4) : Matrix4x4
		{
			return output != null
				? output.copyFrom(_cameraData.worldToScreen)
				: _cameraData.worldToScreen.clone();
		}
		
		public function getScreenToWorld(output : Matrix4x4) : Matrix4x4
		{
			return output != null
				? output.copyFrom(_cameraData.screenToWorld)
				: _cameraData.screenToWorld.clone();
		}
		
		public function getProjection(output : Matrix4x4) : Matrix4x4
		{
			return output != null
				? output.copyFrom(_cameraData.projection)
				: _cameraData.projection.clone();
		}
	}
}