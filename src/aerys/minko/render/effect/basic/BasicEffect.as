package aerys.minko.render.effect.basic
{
	import aerys.minko.render.RenderTarget;
	import aerys.minko.render.effect.IRenderingEffect;
	import aerys.minko.render.effect.SinglePassEffect;
	import aerys.minko.render.effect.animation.AnimationShaderPart;
	import aerys.minko.render.effect.animation.AnimationStyle;
	import aerys.minko.type.enum.Blending;
	import aerys.minko.type.enum.CompareMode;
	import aerys.minko.render.renderer.RendererState;
	import aerys.minko.render.resource.Texture3DResource;
	import aerys.minko.render.shader.SValue;
	import aerys.minko.scene.data.StyleStack;
	import aerys.minko.scene.data.TransformData;
	import aerys.minko.type.animation.AnimationMethod;
	import aerys.minko.type.math.Vector4;
	
	import flash.utils.Dictionary;
	
	[StyleParameter(name="basic diffuse map", type="texture")]
	[StyleParameter(name="basic diffuse multiplier", type="color")]
	
	public class BasicEffect extends SinglePassEffect implements IRenderingEffect
	{
		private static const ANIMATION	: AnimationShaderPart	= new AnimationShaderPart();
		
		public function BasicEffect(priority		: Number		= 0,
								  	renderTarget	: RenderTarget	= null)
		{
			super(priority, renderTarget);
		}
		
		override public function fillRenderState(state		: RendererState, 
												 style		: StyleStack, 
												 transform	: TransformData, 
												 world		: Dictionary) : Boolean
		{
			super.fillRenderState(state, style, transform, world);
			
			state.priority	= state.priority + .5;
			
			if (state.blending != Blending.NORMAL)
				state.priority -= .5;
			
			return true;
		}
		
		override protected function getOutputPosition() : SValue
		{
			var animationMethod		: uint		= getStyleConstant(AnimationStyle.METHOD, AnimationMethod.DISABLED) as uint;
			var maxInfluences		: uint		= getStyleConstant(AnimationStyle.MAX_INFLUENCES, 0) as uint;
			var numBones			: uint		= getStyleConstant(AnimationStyle.NUM_BONES, 0) as uint;
			var vertexPosition		: SValue	= ANIMATION.getVertexPosition(animationMethod, maxInfluences, numBones);
			
			return multiply4x4(vertexPosition, localToScreenMatrix);
		}
		
		override protected function getOutputColor() : SValue
		{
			var diffuse : SValue	= null;
			
			if (styleIsSet(BasicStyle.DIFFUSE))
			{
				var diffuseStyle	: Object 	= getStyleConstant(BasicStyle.DIFFUSE);
				
				if (diffuseStyle is uint || diffuseStyle is Vector4)
					diffuse = getStyleParameter(4, BasicStyle.DIFFUSE);
				else if (diffuseStyle is Texture3DResource)
					diffuse = sampleTexture(BasicStyle.DIFFUSE, interpolate(vertexUV));
				else
					throw new Error('Invalid BasicStyle.DIFFUSE value.');
			}
			else
				diffuse = float4(interpolate(vertexRGBColor).rgb, 1.);
			
			if (styleIsSet(BasicStyle.DIFFUSE_MULTIPLIER))
				diffuse.scaleBy(copy(getStyleParameter(4, BasicStyle.DIFFUSE_MULTIPLIER)));
						
			return diffuse;
		}
		
		override public function getDataHash(styleData		: StyleStack,
												transformData	: TransformData,
												worldData		: Dictionary) : String
		{
			var hash 			: String	= "basic";
			var diffuseStyle 	: Object 	= styleData.isSet(BasicStyle.DIFFUSE)
											  ? styleData.get(BasicStyle.DIFFUSE)
											  : null;
			
			if (diffuseStyle == null)
				hash += '_colorFromVertex';
			else if (diffuseStyle is uint || diffuseStyle is Vector4)
				hash += '_colorFromConstant';
			else if (diffuseStyle is Texture3DResource)
				hash += '_colorFromTexture';
			else
				throw new Error('Invalid BasicStyle.DIFFUSE value');
			
			if (styleData.isSet(BasicStyle.DIFFUSE_MULTIPLIER))
				hash += "_diffuseMultiplier";
			
			hash += ANIMATION.getDataHash(styleData, transformData, worldData)
			
			return hash;
		}
	}
}
