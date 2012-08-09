package aerys.minko.scene.node
{
	import aerys.minko.ns.minko_scene;
	import aerys.minko.scene.controller.AbstractController;
	import aerys.minko.scene.controller.IRebindableController;
	import aerys.minko.scene.data.TransformDataProvider;
	import aerys.minko.type.Signal;
	import aerys.minko.type.clone.CloneOptions;
	import aerys.minko.type.clone.ControllerCloneAction;
	import aerys.minko.type.math.Matrix4x4;
	
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import mx.messaging.AbstractConsumer;

	/**
	 * The base class to extend in order to create new scene node types.
	 *  
	 * @author Jean-Marc Le Roux
	 * 
	 */
	public class AbstractSceneNode implements ISceneNode
	{
		use namespace minko_scene;
		
		private static var _id			: uint							= 0;

		private var _name				: String						= null;
		private var _root				: ISceneNode					= null;
		private var _parent				: Group							= null;
		
		private var _transformData		: TransformDataProvider			= new TransformDataProvider();
		private var _transform			: Matrix4x4						= new Matrix4x4();
		
		private var _privateControllers	: Vector.<AbstractController>	= new <AbstractController>[];
		private var _publicControllers	: Vector.<AbstractController>	= new <AbstractController>[];
		
		private var _added				: Signal						= new Signal('AbstractSceneNode.added');
		private var _removed			: Signal						= new Signal('AbstractSceneNode.removed');
		private var _addedToScene		: Signal						= new Signal('AbstractSceneNode.addedToScene');
		private var _removedFromScene	: Signal						= new Signal('AbstractSceneNode.removedFromScene');
		private var _controllerAdded	: Signal						= new Signal('AbstractSceneNode.controllerAdded');
		private var _controllerRemoved	: Signal						= new Signal('AbstractSceneNode.controllerRemoved');

		public function get name() : String
		{
			return _name;
		}
		public function set name(value : String) : void
		{
			_name = value;
		}
		
		public function get parent() : Group
		{
			return _parent;
		}
		public function set parent(value : Group) : void
		{
			if (value == _parent)
				return ;
			
			// remove child
			if (_parent)
			{
				var oldParent : Group = _parent;
				
				oldParent._children.splice(
					oldParent.getChildIndex(this),
					1
				);
				
				parent._numChildren--;
				oldParent.descendantRemoved.execute(oldParent, this);
				
				_parent = null;
				_removed.execute(this, oldParent);
			}
			
			// set parent
			_parent = value;
			
			// add child
			if (_parent)
			{
				_parent._children[_parent.numChildren] = this;
				_parent._numChildren++;
				_parent.descendantAdded.execute(_parent, this);
				
				_added.execute(this, _parent);
			}
		}
		
		public function get root() : ISceneNode
		{
			return _root;
		}
		
		public function get transform() : Matrix4x4
		{
			return _transform;
		}
		
		public function get localToWorld() : Matrix4x4
		{
			return _transformData.localToWorld;
		}
		
		public function get worldToLocal() : Matrix4x4
		{
			return _transformData.worldToLocal;
		}
		
		public function get added() : Signal
		{
			return _added;
		}
		
		public function get removed() : Signal
		{
			return _removed;
		}

		public function get addedToScene() : Signal
		{
			return _addedToScene;
		}
		
		public function get removedFromScene() : Signal
		{
			return _removedFromScene;
		}
		
		public function get numControllers() : uint
		{
			return _publicControllers.length;
		}
		
		public function get controllerAdded() : Signal
		{
			return _controllerAdded;
		}
		
		public function get controllerRemoved() : Signal
		{
			return _controllerRemoved;
		}
		
		protected function get transformData() : TransformDataProvider
		{
			return _transformData;
		}
		
		public function AbstractSceneNode()
		{
			initialize();
		}
		
		private function initialize() : void
		{
			_name = getDefaultSceneName(this);
			_root = this;
			
			_added.add(addedHandler);
			_removed.add(removedHandler);
			_addedToScene.add(addedToSceneHandler);
			_removedFromScene.add(removedFromSceneHandler);
			
			_transform.changed.add(transformChangedHandler);
		}
		
		protected function addedHandler(child : ISceneNode, parent : Group) : void
		{
			_root = _parent ? _parent.root : this;
			if (_root is Scene)
				_addedToScene.execute(this, _root);
			
			if (child === this)
			{
				_parent.localToWorld.changed.add(transformChangedHandler);
				transformChangedHandler(_parent.transform);
			}
		}
		
		protected function removedHandler(child : ISceneNode, parent : Group) : void
		{
			// update root
			var oldRoot : ISceneNode = _root;
			
			_root = _parent ? _parent.root : this;
			if (oldRoot is Scene)
				_removedFromScene.execute(this, oldRoot);
			
			if (child === this)
				parent.localToWorld.changed.remove(transformChangedHandler);
		}
		
		protected function addedToSceneHandler(child : ISceneNode, scene : Scene) : void
		{
			// nothing
		}
		
		protected function removedFromSceneHandler(child : ISceneNode, scene : Scene) : void
		{
			// nothing
		}
		
		protected function transformChangedHandler(transform	: Matrix4x4) : void
		{
			if (_parent)
			{
				localToWorld.lock()
					.copyFrom(_transform)
					.append(_parent.localToWorld)
					.unlock();
			}
			else
				localToWorld.copyFrom(_transform);
			
			worldToLocal.lock()
				.copyFrom(localToWorld)
				.invert()
				.unlock();
		}
		
		public function addController(controller : AbstractController) : ISceneNode
		{
			_publicControllers.push(controller);
			
			controller.addTarget(this);
			_controllerAdded.execute(this, controller);
			
			return this;
		}
		
		public function removeController(controller : AbstractController) : ISceneNode
		{
			var numControllers	: uint = _publicControllers.length - 1;
			
			_publicControllers[_publicControllers.indexOf(controller)] = _publicControllers[numControllers];
			_publicControllers.length = numControllers;
			
			controller.removeTarget(this);
			_controllerRemoved.execute(this, controller);
			
			return this;
		}
		
		public function removeAllControllers() : ISceneNode
		{
			while (numControllers)
				removeController(getController(0));
			
			return this;
		}
		
		public function getController(index : uint) : AbstractController
		{
			return _publicControllers[index];
		}
		
		public function getControllersByType(type			: Class,
											 controllers	: Vector.<AbstractController> = null) : Vector.<AbstractController>
		{
			controllers ||= new Vector.<AbstractController>();
			
			var nbControllers : uint = numControllers;
			
			for (var i : int = 0; i < nbControllers; ++i)
			{
				var ctrl 	: AbstractController	= getController(i);
				
				if (ctrl is type)
					controllers.push(ctrl);
			}
			
			return controllers;
		}
		
		public static function getDefaultSceneName(scene : ISceneNode) : String
		{
			var className : String = getQualifiedClassName(scene);

			return className.substr(className.lastIndexOf(':') + 1)
				   + '_' + (++_id);
		}
		
		public function clone() : ISceneNode
		{
			throw new Error('Must be overriden');
		}
		
		public function recursiveClone(cloneOptions : CloneOptions) : ISceneNode
		{
			var objController	: Object;
			var controller		: AbstractController;
			var objNode			: Object;
			
			// fill up 2 dics with all nodes and controllers
			var nodeMap			: Dictionary = new Dictionary();
			var controllerMap	: Dictionary = new Dictionary();
			listItems(root, nodeMap, controllerMap);
			
			// clone controllers with respect with instructions
			cloneControllers(controllerMap, cloneOptions);
			
			// clone nodes.
			for (objNode in nodeMap)
				nodeMap[objNode] = ISceneNode(objNode).clone();
			
			// rebind all controller dependencies.
			rebindControllerDependencies(controllerMap, nodeMap, cloneOptions);
			
			// rebuild tree
			for (objNode in nodeMap)
				if (objNode is Group)
				{
					var clone		: Group	= nodeMap[objNode];
					var numChildren	: uint	= objNode.numChildren;
					
					for (var childId : uint = 0; childId < numChildren; ++childId)
						clone.addChild(nodeMap[objNode.getChildAt(childId)]);
				}
			
			// add cloned/rebinded/original controllers to clones
			for (objNode in nodeMap)
			{
				var numControllers : uint = objNode.numControllers;
				
				for (var controllerId : uint = 0; controllerId < numControllers; ++controllerId)
				{
					controller = controllerMap[objNode.getController(controllerId)];
					if (controller != null)
						nodeMap[objNode].addController(controller);
				}
			}
			
			return nodeMap[root]; 
		}
		
		private function listItems(node			: ISceneNode,
								   nodes		: Dictionary,
								   controllers	: Dictionary) : void
		{
			var numControllers	: uint = node.numControllers;
			for (var controllerId : uint = 0; controllerId < numControllers; ++controllerId)
				controllers[node.getController(controllerId)] = true;
			
			nodes[node] = true;
			
			if (node is Group)
			{
				var group		: Group = Group(node);
				var numChildren	: uint	= group.numChildren;
				
				for (var childId : uint = 0; childId < numChildren; ++childId)
					listItems(group.getChildAt(childId), nodes, controllers);
			}
		}
		
		private function cloneControllers(controllerMap : Dictionary, cloneOptions : CloneOptions) : void
		{
			for (var objController : Object in controllerMap)
			{
				var controller	: AbstractController = AbstractController(objController);
				var action		: uint				 = cloneOptions.getActionForController(controller);
				
				if (action == ControllerCloneAction.CLONE)
					controllerMap[controller] = controller.clone();
				else if (action == ControllerCloneAction.REASSIGN)
					controllerMap[controller] = controller;
				else if (action == ControllerCloneAction.IGNORE)
					controllerMap[controller] = null;
			}
		}
		
		private function rebindControllerDependencies(controllerMap	: Dictionary,
													  nodeMap		: Dictionary,
													  cloneOptions	: CloneOptions) : void
		{
			for (var objController : Object in controllerMap)
			{
				var controller	: AbstractController	= AbstractController(objController);
				var action		: uint					= cloneOptions.getActionForController(controller);
				
				if (controller is IRebindableController && action == ControllerCloneAction.CLONE)
					IRebindableController(controllerMap[controller]).rebindDependencies(nodeMap, controllerMap);
			}
		}
	}
}