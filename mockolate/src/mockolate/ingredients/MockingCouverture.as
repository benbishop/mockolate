package mockolate.ingredients
{	 
	import asx.array.contains;
	import asx.array.detect;
	import asx.array.empty;
	import asx.array.filter;
	import asx.array.map;
	import asx.array.reject;
	import asx.fn.getProperty;
	import asx.string.substitute;
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import mockolate.decorations.Decorator;
	import mockolate.decorations.EventDispatcherDecorator;
	import mockolate.decorations.InvocationDecorator;
	import mockolate.decorations.rpc.HTTPServiceDecorator;
	import mockolate.errors.ExpectationError;
	import mockolate.errors.InvocationError;
	import mockolate.errors.MockolateError;
	import mockolate.errors.VerificationError;
	import mockolate.ingredients.MockolatierMaster;
	import mockolate.ingredients.answers.Answer;
	import mockolate.ingredients.answers.CallsAnswer;
	import mockolate.ingredients.answers.CallsSuperAnswer;
	import mockolate.ingredients.answers.DispatchesEventAnswer;
	import mockolate.ingredients.answers.MethodInvokingAnswer;
	import mockolate.ingredients.answers.ReturnsAnswer;
	import mockolate.ingredients.answers.ThrowsAnswer;
	
	import mx.rpc.http.HTTPService;
	
	import org.hamcrest.Matcher;
	import org.hamcrest.StringDescription;
	import org.hamcrest.collection.IsArrayMatcher;
	import org.hamcrest.collection.array;
	import org.hamcrest.collection.emptyArray;
	import org.hamcrest.core.anyOf;
	import org.hamcrest.core.anything;
	import org.hamcrest.core.describedAs;
	import org.hamcrest.date.dateEqual;
	import org.hamcrest.number.greaterThan;
	import org.hamcrest.number.greaterThanOrEqualTo;
	import org.hamcrest.number.lessThan;
	import org.hamcrest.number.lessThanOrEqualTo;
	import org.hamcrest.object.equalTo;
	import org.hamcrest.object.instanceOf;
	import org.hamcrest.object.nullValue;
	import org.hamcrest.text.re;
	
	use namespace mockolate_ingredient;
	
	/**
	 * Mock and Stub behaviour of the target, such as:
	 * 
	 * <ul>
	 * <li>return values, </li>
	 * <li>calling functions, </li>
	 * <li>dispatching events, </li>
	 * <li>throwing errors. </li>
	 * </ul>
	 * 
	 * @author drewbourne
	 */
	public class MockingCouverture 
		extends Couverture 
		implements IMockingMethodCouverture, IMockingGetterCouverture, IMockingSetterCouverture, IMockingCouverture
	{
		private var _invokedAs:Object;
		private var _expectations:Array;
		private var _mockExpectations:Array;
		private var _stubExpectations:Array;
		private var _currentExpectation:Expectation;
		private var _expectationsAsMocks:Boolean;
		private var _decoratorClassesByClass:Dictionary;
		private var _decorations:Array;
		private var _decorationsByClass:Dictionary;
		private var _invocationDecorations:Array;
		
		/**
		 * Constructor. 
		 */
		public function MockingCouverture(mockolate:Mockolate)
		{
			super(mockolate);
			
			_expectations = [];
			_mockExpectations = [];
			_stubExpectations = [];
			_expectationsAsMocks = true;
			_decorations = [];
			_invocationDecorations = [];
			_decorationsByClass = new Dictionary();
			
			_decoratorClassesByClass = new Dictionary();
			_decoratorClassesByClass[IEventDispatcher] = EventDispatcherDecorator;
			_decoratorClassesByClass[EventDispatcher] = EventDispatcherDecorator;
			_decoratorClassesByClass[HTTPService] = HTTPServiceDecorator;
		}
		
		//
		//	Public API
		//
		
		//
		//	mocking and stubbing behaviours
		//
		
		/**
		 * Use <code>mock()</code> when you want to ensure that method or 
		 * property is called.
		 * 
		 * Sets the expectation mode to create required Expectations. Required 
		 * Expectations will be checked when <code>verify(instance)</code> is 
		 * called.
		 * 
		 * @see mockolate#mock()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("toString").returns("[Instance]");
		 * </listing>
		 */
		public function mock():MockingCouverture
		{
			_expectationsAsMocks = true;
			return this;
		}
		
		/**
		 * Use <code>stub()</code> when you want to add behaviour to a method
		 * or property that MAY be used. 
		 * 
		 * Sets the expectation mode to create possible expectations. Possible 
		 * Expectations will NOT be checked when <code>verify(instance)</code> 
		 * is called. They are used to define support behaviour.
		 * 
		 * @see mockolate#stub()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	stub(instance).method("toString").returns("[Instance]");
		 * </listing> 
		 */
		public function stub():MockingCouverture
		{
			_expectationsAsMocks = false;
			return this;
		}
		
		/**
		 * Defines an Expectation of the given method name.
		 * 
		 * @param name Name of the method to expect.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("toString").returns("[Instance]");
		 * </listing>
		 */
		public function method(name:String/*, ns:String=null*/):IMockingMethodCouverture
		{
			// FIXME this _really_ should check that the method actually exists on the Class we are mocking
			// FIXME when this checks if the method exists, remember we have to support Proxy as well! 
			
			createMethodExpectation(name, null);
			
			// when expectation mode is mock
			// than should be called at least once
			// -- will be overridden if set by the user. 
			if (mockolate.isStrict)
				atLeast(1);
			
			return this;
		}
		
		// TODO Should return a MockingPropertyCouverture that hides method() and property() and provides only arg() not args()
		[Deprecated(since="0.8.0", replacement="#getter() or #setter()")]
		/**
		 * Defines an Expectation to get a property value.
		 * 
		 * @param name Name of the method to expect.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	stub(instance).property("name").returns("[Instance]");
		 * </listing>  
		 */
		public function property(name:String/*, ns:String=null*/):MockingCouverture
		{
			// FIXME this _really_ should check that the property actually exists on the Class we are mocking
			// FIXME when this checks if the method exists, remember we have to support Proxy as well!
			
			createPropertyExpectation(name, null);
			
			return this;
		}
		
		/**
		 * Defines an Expectation to get a property value.
		 * 
		 * @param name Name of the property
		 * 
		 * @example
		 * <listing version="3.0">
		 * 	stub(instance).getter("name").returns("Current Name");
		 * </listing>
		 */
		public function getter(name:String/*, ns:String=null*/):IMockingGetterCouverture
		{
			createGetterExpectation(name);
			
			return new MockingGetterCouverture(this.mockolate);
		}
		
		/**
		 * Defines an Expectation to set a property value.
		 * 
		 * @param name Name of the property
		 * 
		 * @example
		 * <listing version="3.0">
		 * 	stub(instance).setter("name").arg("New Name");
		 * </listing>
		 */
		public function setter(name:String/*, ns:String=null*/):IMockingSetterCouverture
		{
			createSetterExpectation(name);
			
			return new MockingSetterCouverture(this.mockolate);
		}
		
		/**
		 * Use <code>arg()</code> to define a single value or Matcher as the 
		 * expected arguments. Typically used with property expectations to 
		 * define the expected argument value for the property setter.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).property("enabled").arg(Boolean);
		 * </listing> 
		 */
		public function arg(value:Object):IMockingSetterCouverture
		{
			// FIXME this _really_ should check that the method or property accepts the number of matchers given.
			// we can ignore the types of the matchers though, it will fail when run if given incorrect values.
			
			setArgs([value]);
			return this;
		}
		
		/**
		 * Use <code>args()</code> to define the values or Matchers to expect as
		 * arguments when the method (or property) is invoked. 
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("add").args(Number, Number).returns(42);
		 * </listing> 
		 */
		public function args(... rest):IMockingMethodCouverture
		{
			// FIXME this _really_ should check that the method or property accepts the number of matchers given.
			// we can ignore the types of the matchers though, it will fail when run if given incorrect values.
			
			setArgs(rest);
			return this;
		}
		
		/**
		 * Use <code>noArgs()</code> to define that arguments are not expected
		 * when the method is invoked.	
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("toString").noArgs();
		 * </listing> 
		 */
		public function noArgs():IMockingMethodCouverture
		{
			// FIXME this _really_ should check that the method or property accepts no arguments.
			
			setNoArgs();
			return this;
		}
		
		/**
		 * Use <code>anyArgs()</code> to define that the current Expectation 
		 * should be invoked for any arguments.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("arbitrary").anyArgs();
		 * 
		 *	instance.arbitrary(1, 2, 3);	
		 * </listing> 
		 */
		public function anyArgs():IMockingMethodCouverture
		{
			setAnyArgs();
			return this;
		}
		
		/**
		 * Sets the value to return when the current Expectation is invoked.  
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("toString").returns("[Instance]");
		 * 
		 *	trace(instance.toString());
		 *	// "[Instance]" 
		 * </listing>
		 */
		public function returns(value:*, ...values):IMockingCouverture
		{
			// FIXME first set returns() value wins, should be last.
			
			addReturns.apply(null, [ value ].concat(values));
			return this;
		}
		
		/**
		 * Causes the current Expectation to throw the given Error when invoked. 
		 * 
		 * @example 
		 * <listing version="3.0">
		 *	mock(instance).method("explode").throws(new ExplodyError("Boom!"));
		 *	
		 *	try
		 *	{
		 *		instance.explode();
		 *	}
		 *	catch (error:ExplodyError)
		 *	{
		 *		// error handling.
		 *	}
		 * </listing>
		 */
		public function throws(error:Error):IMockingCouverture
		{
			addThrows(error);
			return this;
		}
		
		/**
		 * Calls the given Function with the given arguments when the current
		 * Expectation is invoked. 
		 * 
		 * Note: does NOT pass anything from the Invocation to the function. 
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("message").calls(function(a:int, b:int):void {
		 *		trace("message", a, b);
		 *		// "message 1 2"
		 *	}, [1, 2]);
		 * </listing> 
		 */
		public function calls(fn:Function, args:Array=null):IMockingCouverture
		{
			addCalls(fn, args);
			return this;
		}
		
		/**
		 * Causes the current Expectation to dispatch the given Event with an 
		 * optional delay when invoked. 
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("update").dispatches(new Event("updated"), 300);
		 * </listing>
		 */
		public function dispatches(event:Event, delay:Number=0):IMockingCouverture
		{
			addDispatches(event, delay);
			return this;
		}
		
		/**
		 * Causes the current Expectation to invoke the given Answer subclass. 
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("update").answers(new CustomAnswer());
		 * </listing>
		 */
		public function answers(answer:Answer):IMockingCouverture
		{
			addAnswer(answer);
			return this;
		}
		
		//
		//	verification behaviours
		//
		
		/**
		 * Sets the current Expectation to expect to be called the given 
		 * number of times. 
		 * 
		 * If the Expectation has not been invoked the correct number of times 
		 * when <code>verify()</code> is called then a	VerifyFailedError will 
		 * be thrown.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").times(3);
		 * 
		 *	instance.say();
		 *	instance.say();
		 *	instance.say();
		 *	
		 *	verify(instance);
		 * </listing>
		 */
		public function times(n:int):IMockingCouverture
		{
			setInvokeCount(lessThanOrEqualTo(n), equalTo(n));
			return this;
		}
		
		/**
		 * Sets the current Expectation to expect not to be called. 
		 * 
		 * If the Expectation has been invoked then when <code>verify()</code> 
		 * is called then a	 VerifyFailedError will be thrown.
		 * 
		 * @see #times()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("deprecatedMethod").never();
		 * </listing>
		 */
		public function never():IMockingCouverture
		{
			return times(0);
		}
		
		/**
		 * Sets the current Expectation to expect to be called once.
		 * 
		 * @see #times()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").once();
		 * 
		 *	instance.say();
		 * 
		 *	verify(instance);
		 * </listing> 
		 */
		public function once():IMockingCouverture
		{
			return times(1);
		}
		
		/**
		 * Sets the current Expectation to expect to be called two times.
		 * 
		 * @see #times()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").twice();
		 * 
		 *	instance.say();
		 *	instance.say();
		 * 
		 *	verify(instance);
		 * </listing> 
		 */
		public function twice():IMockingCouverture
		{
			return times(2);
		}
		
		// at the request of Brian LeGros we have thrice()
		/**
		 * Sets the current Expectation to expect to be called three times.
		 * 
		 * @see #times()
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").thrice();
		 * 
		 *	instance.say();
		 *	instance.say();
		 *	instance.say();
		 * 
		 *	verify(instance);
		 * </listing>  
		 */
		public function thrice():IMockingCouverture
		{
			return times(3);
		}
		
		/**
		 * Sets the current Expectation to expect to be called at least the 
		 * given number of times.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").atLeast(2);
		 * 
		 *	instance.say();
		 *	instance.say();
		 *	instance.say();
		 * 
		 *	verify(instance);
		 * </listing> 
		 */
		public function atLeast(n:int):IMockingCouverture
		{
			setInvokeCount(greaterThanOrEqualTo(0), greaterThanOrEqualTo(n));
			return this;
		}
		
		/**
		 * Sets the current Expectation to expect to be called at most the 
		 * given number of times.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("say").atMost(2);
		 * 
		 *	instance.say();
		 * 
		 *	verify(instance);
		 * </listing> 
		 */
		public function atMost(n:int):IMockingCouverture
		{
			setInvokeCount(lessThanOrEqualTo(n), lessThanOrEqualTo(n));
			return this;
		}
		
		/**
		 * Sets the current Expectation to expect to be called in order.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance1).method("sort").ordered("execution order sensitive");
		 *	mock(instance2).method("sort").ordered("execution order sensitive");
		 * </listing>
		 */		   
		public function ordered(sequence:Sequence):IMockingCouverture
		{
			addOrdered(sequence);
			return this;
		}
		
		/**
		 * Sets the current Expectation to invoke the super method or property.
		 * 
		 * @example
		 * <listing version="3.0">
		 *	mock(instance).method("addEventListener").anyArgs().callsSuper();
		 * </listing>
		 */
		public function callsSuper():IMockingCouverture
		{
			addCallsSuper();
			return this;
		}
		
		/**
		 * @inheritDoc
		 */
		public function pass():IMockingCouverture
		{
			return callsSuper();
		}
		
		/**
		 * @example
		 * <listing version="3.0">
		 *	(mock(httpService).decorate(HTTPService) as HTTPServiceDecorator)
		 *		.send("What is the ultimate answer to life, the universe, everything?")
		 *		.result(42)
		 * </listing> 
		 */
		public function decorate(classToDecorate:Class, decoratorClass:Class = null):Decorator 
		{
			// the decorators may define new expectations
			// as such we need to reinstate the current expecation
			// after the decorator has been created.
			
			var previousExpectation:Expectation = _currentExpectation;
			
			var decorator:Decorator = createDecoratorFor(classToDecorate, decoratorClass);
			
			_currentExpectation = previousExpectation;
			
			return decorator;
		}
		
		//
		//	Decorators
		//
		
		/**
		 * 
		 */
		public function asEventDispatcher():EventDispatcherDecorator
		{
			return stub().decorate(IEventDispatcher) as EventDispatcherDecorator;
		}
		
		/**
		 * 
		 */
		public function asHTTPService():HTTPServiceDecorator
		{
			return stub().decorate(HTTPService) as HTTPServiceDecorator;
		}
		
		//
		//	Internal API
		//
		
		/**
		 * Gets a copy of the Array of Expectations.
		 * 
		 * @private
		 */
		mockolate_ingredient function get expectations():Array
		{
			return _expectations.slice(0);
		}
		
		/**
		 * Finds the first Expectation that returns <code>true</code> for
		 * <code>Expectation.eligible(Invocation)</code> with the given Invocation.
		 * 
		 * @private
		 */
		protected function findEligibleExpectation(invocation:Invocation):Expectation
		{
			var expectation:Expectation = detect(_mockExpectations, isEligibleExpectation, invocation) as Expectation;

			if (!expectation)
				expectation = detect(_stubExpectations, isEligibleExpectation, invocation) as Expectation;
			
			if (!expectation && this.mockolate.isStrict)
			{
				throw new InvocationError(
					["No Expectation defined for Invocation:{}", [invocation]], 
					invocation, this.mockolate, this.mockolate.target);
			}
			
			return expectation;
		}
		
		/**
		 * @private 
		 */
		protected function isEligibleExpectation(expectation:Expectation, invocation:Invocation):Boolean 
		{
			return expectation.eligible(invocation);
		}
		
		/**
		 * Called when a method or property is invoked on an instance created by 
		 * Mockolate.  
		 * 
		 * @private
		 */
		override mockolate_ingredient function invoked(invocation:Invocation):void
		{
			invokeDecorators(invocation);
			
			invokeExpectation(invocation);
		}
		
		/**
		 * Invoke Decorators.
		 * 
		 * @private
		 */
		protected function invokeDecorators(invocation:Invocation):void 
		{
			for each (var decorator:Decorator in _invocationDecorations)
			{
				decorator.invoked(invocation);
			}
		}
		
		/**
		 * Find and invoke the first eligible Expectation. 
		 * 
		 * @private
		 */
		protected function invokeExpectation(invocation:Invocation):void
		{
			var expectation:Expectation = findEligibleExpectation(invocation);
			if (expectation)
			{
				expectation.invoke(invocation); 
			}
		}
		
		/**
		 * Create an Expectation.
		 * 
		 * @see #createPropertyExpectation
		 * @see #createMethodExpectation
		 * 
		 * @private
		 */
		protected function createExpectation(name:String, ns:String=null):Expectation
		{
			var expectation:Expectation = new Expectation();
			expectation.name = name;
			
			return expectation;
		}
		
		/**
		 * Adds an Expectation.
		 * 
		 * @private
		 */
		protected function addExpectation(expectation:Expectation):Expectation 
		{
			_expectations[_expectations.length] = expectation;
			
			if (_expectationsAsMocks)
				_mockExpectations[_mockExpectations.length] = expectation;
			else
				_stubExpectations[_stubExpectations.length] = expectation;		
			
			return expectation;
		}
		
		[Deprecated]
		/**
		 * Create an Expectation for a property.
		 * 
		 * @private
		 */
		protected function createPropertyExpectation(name:String, ns:String=null):void
		{
			_currentExpectation = createExpectation(name, ns);
			_currentExpectation.invocationType = InvocationType.GETTER;
			
			addExpectation(_currentExpectation);
			
			// when expectation mode is mock
			// than should be called at least once
			// -- will be overridden if set by the user. 
			if (this.mockolate.isStrict)
				atLeast(1);			   
		}
		
		/**
		 * Creates a Expectation for a getter.
		 * 
		 * @private
		 */
		protected function createGetterExpectation(name:String, ns:String=null):void 
		{
			_currentExpectation = createExpectation(name, ns);
			_currentExpectation.invocationType = InvocationType.GETTER;
			
			addExpectation(_currentExpectation);
			
			// when expectation mode is mock
			// than should be called at least once
			// -- will be overridden if set by the user. 
			if (this.mockolate.isStrict)
				atLeast(1);	
		}
		
		/**
		 * Creates an Expectation for a setter.
		 * 
		 * @private
		 */
		protected function createSetterExpectation(name:String, ns:String=null):void 
		{
			_currentExpectation = createExpectation(name, ns);
			_currentExpectation.invocationType = InvocationType.SETTER;
			
			addExpectation(_currentExpectation);
			
			// when expectation mode is mock
			// than should be called at least once
			// -- will be overridden if set by the user. 
			if (this.mockolate.isStrict)
				atLeast(1);				
		}
		
		/**
		 * Create an Expectation for a method.
		 * 
		 * @private
		 */
		protected function createMethodExpectation(name:String, ns:String=null):void
		{
			_currentExpectation = createExpectation(name, ns);
			_currentExpectation.invocationType = InvocationType.METHOD;
			
			addExpectation(_currentExpectation);						
		}
		
		/**
		 * @private
		 */
		protected function setArgs(args:Array):void
		{	
			_currentExpectation.argsMatcher = describedAs(
				new StringDescription().appendList("", ",", "", args).toString(), 
				new IsArrayMatcher(map(args, valueToMatcher)));
		}
		
		/**
		 * @private
		 */
		protected function setNoArgs():void
		{
			_currentExpectation.argsMatcher = describedAs("", anyOf(nullValue(), emptyArray()));
		}
		
		/**
		 * @private
		 */
		protected function setAnyArgs():void 
		{
			_currentExpectation.argsMatcher = anything();
		}		 
		
		// FIXME rename setReceiveCount to something better
		/**
		 * @private
		 */
		protected function setInvokeCount(
			eligiblityMatcher:Matcher, 
			verificationMatcher:Matcher):void
		{
			_currentExpectation.invokeCountEligiblityMatcher = eligiblityMatcher;
			_currentExpectation.invokeCountVerificationMatcher = verificationMatcher;
		}
		
		/**
		 * @private
		 */
		protected function addAnswer(answer:Answer):void
		{
			if (answer)
				_currentExpectation.addAnswer(answer);
		}
		
		/**
		 * @private
		 */
		protected function addThrows(error:Error):void
		{
			addAnswer(new ThrowsAnswer(error));
		}
		
		/**
		 * @private
		 */
		protected function addDispatches(event:Event, delay:Number=0):void
		{
			var eventDispatcherDecorator:EventDispatcherDecorator = decorate(IEventDispatcher) as EventDispatcherDecorator;
			
			addAnswer(new DispatchesEventAnswer(eventDispatcherDecorator.eventDispatcher, event, delay));
		}
		
		/**
		 * @private
		 */
		protected function addCalls(fn:Function, args:Array=null):void
		{
			addAnswer(new CallsAnswer(fn, args));
		}
		
		/**
		 * @private
		 */
		protected function addReturns(value:*, ...values):void
		{
			addAnswer(new ReturnsAnswer([ value ].concat(values)));
		}
		
		/**
		 * @private 
		 */
		protected function addCallsSuper():void 
		{
			addAnswer(new CallsSuperAnswer());
		}
		
		/**
		 * @private
		 */
		protected function addOrdered(sequence:Sequence):void 
		{
			sequence.constrainAsNextInSequence(_currentExpectation);
		}
		
		/**
		 * @private
		 */
		protected function createDecoratorFor(classToDecorate:Class, decoratorClass:Class):Decorator
		{
			if (!decoratorClass)
				decoratorClass = _decoratorClassesByClass[classToDecorate];
			
			if (!decoratorClass)
				throw new MockolateError(["No Decorator registered for {0}", [classToDecorate]], this.mockolate, this.mockolate.target);
			
			var decorator:Decorator = _decorationsByClass[classToDecorate];
			
			if (!decorator)
			{
				decorator = new decoratorClass(this.mockolate);
				
				_decorations[_decorations.length] = decorator;
				_decorationsByClass[classToDecorate] = decorator; 
				
				if (decorator is InvocationDecorator)
					_invocationDecorations[_invocationDecorations.length] = decorator;
			}
			
			return decorator;
		}
		
		/**
		 * @private
		 */
		override mockolate_ingredient function verify():void
		{
			// mock expectations are always verified
			
			var unmetExpectations:Array = reject(_mockExpectations, verifyExpectation);
			if (!empty(unmetExpectations))
			{
				var message:String = unmetExpectations.length.toString();
				
				message += unmetExpectations.length == 1 
					? " unmet Expectation"
					: " unmet Expectations";
				
				for each (var expectation:Expectation in unmetExpectations)
				{
					message += "\n\t";
					// TODO move to mockolate.targetClassName
					message += getQualifiedClassName(this.mockolate.targetClass);
					
					if (this.mockolate.name)
						message += "<\"" + this.mockolate.name + "\">";
					
					// TOOD include more description from the Expectation
					message += expectation.toString();
				}
				
				throw new ExpectationError(
					message, 
					unmetExpectations, 
					this.mockolate, 
					this.mockolate.target);
			}
			
			map(_mockExpectations, verifyExpectation);
			
			// stub expectations are not verified
		}	
		
		/**
		 * @private 
		 */
		protected function verifyExpectation(expectation:Expectation):Boolean 
		{
			return expectation.satisfied;			
		}
	}
}
