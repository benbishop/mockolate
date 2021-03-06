package mockolate.ingredients.proxy
{
	import flash.errors.IllegalOperationError;
	import flash.events.IEventDispatcher;
	
	import mockolate.ingredients.ExpectingCouverture;
	import mockolate.ingredients.MockingCouverture;
	import mockolate.ingredients.Mockolate;
	import mockolate.ingredients.MockolateFactory;
	import mockolate.ingredients.VerifyingCouverture;
	import mockolate.ingredients.mockolate_ingredient;
	
	use namespace mockolate_ingredient;

	/**
	 * ProxyMockolateFactory creates Mockolate instances for use with MockolateProxy.
	 * 
	 * @see MockolateProxy
	 * 
	 * @private
	 * @author drewbourne
	 */
	public class ProxyMockolateFactory implements MockolateFactory
	{
		/**
		 * Constructor. 
		 */
		public function ProxyMockolateFactory()
		{
			super();
		}
		
		/**
		 * ProxyMockolateFactory does not need to prepare classes.
		 * @private 
		 */
		public function prepare(...classes):IEventDispatcher
		{
			throw new IllegalOperationError("ProxyMockolateFactory.prepare() is not needed, use create() only.");
		}
		
		/**
		 * @inheritDoc
		 */
		public function create(classReference:Class, constructorArgs:Array=null, asStrict:Boolean=true, name:String=null):Mockolate 
		{
			var instance:Mockolate = new Mockolate(name);
			instance.targetClass = classReference;
			instance.isStrict = asStrict;		
			instance.mocker = createMocker(instance);
			instance.verifier = createVerifier(instance);
			instance.expecter = createExpecter(instance);
			
			return instance;
		}
		
		/**
		 * @private 
		 */
		protected function createMocker(mockolate:Mockolate):MockingCouverture
		{
			return new MockingCouverture(mockolate);
		}
		
		/**
		 * @private 
		 */
		protected function createVerifier(mockolate:Mockolate):VerifyingCouverture
		{
			return new VerifyingCouverture(mockolate);
		}
		
		/**
		 * @private 
		 */
		protected function createExpecter(mockolate:Mockolate):ExpectingCouverture
		{
			return new ExpectingCouverture(mockolate);
		}
	}
}
