# AGENTS.md

> Context file for AI coding agents working in this codebase.
> This file Extends the root AGENTS.md with information specific to writing tests in this codebase.

### Test Types

**Unit Tests** (`tests/specs/unit/`) — Extend `BaseUnitSpec.cfc` (which extends `coldbox.system.testing.BaseTestCase`). Use `createMock()` and `createStub()` for dependencies. Wrapped in `wrapInTransaction()` for automatic rollback. Use `makePublic()` to test private methods. Use `$getProperty()` to inspect internal state.

**Integration Tests** (`tests/specs/integration/`) — Extend `BaseIntegrationSpec.cfc`. Full ColdBox request cycle via `execute()`. Bearer-token authentication via `authenticate()` helper (issues a real opaque session via `AuthSessionService`, cached per username). Also wrapped in transactions.

**Contract Tests** (`tests/specs/contract/`) — Extend `BaseUnitSpec.cfc`. Hit real external APIs (UAT environments). Use `debug()` output to capture real responses for fixture generation. Name pattern: `{Name}ContractTest.cfc`.

### Test Fixtures

- **CFC Fixtures:** `tests/resources/fixtures/{Name}Fixtures.cfc` — Factory methods returning structs for test data
- **JSON Fixtures:** `tests/resources/fixtures/{domain}/` — Real API response snapshots for gateway mocking
- **Gateway Fixtures:** `tests/resources/fixtures/gateways/{name}/` — Per-gateway fixture directories
- **CSV Test Data:** `tests/resources/{state}Licenses/` — License data for maintenance tests

## Contract Tests

Contract tests are a type of test that ensures that the contract between two systems is upheld. In our case, this usually means ensuring that our gateways are properly formatting requests and responses to and from 3rd party APIs. We also can use the results of these tests to build fixtures for our unit tests.

## Unit Tests

Unit tests are tests that verify the behavior of individual units of code (usually a single component / model / function) in isolation from the rest of the system. In this codebase we use `tests.resources.BaseUnitSpec` as the base spec to extend from when writing unit tests. We treat Quick entities as a single "unit".

### Example by Convention

```cfml
// Unit test pattern
component extends="tests.resources.BaseUnitSpec" {
    
    // any UDF helper methods

    // Test data needed for the below tests
    variables._data = {
        "validKey": "validValue",
        "invalidKey": "invalidValue"
        // etc...
    }

    // lifecycle methods setup/teardown: beforeAll(), afterAll()

    function run() {
        describe( "MyComponent", function() {
            beforeEach( function() {
                // Example 1: instantiate a singleton model
                variables.model = createMock( "models.domain.MyComponent" );
                variables.model.init(); // construtor args if needed
                getWireBox().autowire( variables.model ); // inject dependencies and then onDiComplete() event is triggered
                // Example 2: instantiate a transient model or a singleton that needs to persist state across tests, or a Quick entity
                variables.model = prepareMock( getInstance( "myComponent" ) ); // init and autowire is automatically called
            } );
            it( "does something", function() {
                expect( model.doThing() ).toBe( expectedValue );
            } );
        } );
    }
}
```

### Instantiating Singletons for Unit Tests

Since we will be messing with the internals of singleton objects, instead of using `getInstance()` to instantiate objects, we prefer `createMock()` which always returns a new instance of the object, so we don't have to worry about state leaking between tests. 

Example:
```coldfusion
beforeEach( function( currentSpec ) {
    variables.model = createMock( "models.path.to.model" );
    variables.model.init(); // <-- this is important to ensure the model is properly initialized before we autowire it
    getWireBox().autowire( variables.model ); // <-- ensure dependencies are injected into the model (triggers `onDiComplete()`)
} )
```

### Gateway Unit Tests

Gateways are a bit tricky to test because they are essentially just wrappers around API calls, HTTP requests, or headless browser scrapes. We should limit the actual calls to 3rd party systems as much as possible here. Therefore we should mock the underlying HTTP requests and populate it with saved fixutres.

Here's an example of how to mock the `getHttpRequest()` method in a sample gateway test:

```coldfusion
// static test data that can be used across multiple tests in this spec file
variables._data = {
    "httpResults": {
        "getData": { 
            "200": deSerializeJSON( fileRead( expandPath( "/fixtures/gateways/domain/httpResults-getData-200.json" ) ) ) 
        }
    }
};

function beforeAll() {
    variables.model = createMock( "models.domain.gateways.DomainGateway" );
    getWireBox().autowire( variables.model );
    variables.model.init();

    // Force auth token to be valid (where applicable) 
    variables.model.$( "getAuthToken", { 
        "expires_in": 3600,
        "access_token": "fake-access-token"
    } );
}

it( "can get some data", function() {

    // mock the makeHttpRequest for getting some data
    variables.model.$( "makeHttpRequest", variables._data.httpResults.getData[ "200" ] );
    
    var result = model.getData(); 

    runApiResultExpectations( result );

    // expect our mock httpResponse to have been called with the correct parameters
    expect( variables.model.$once( "makeHttpRequest" ) ).toBeTrue( "Expected makeHttpRequest to be called once" );

} );
```

### Client Unit Tests

Clients wrap gateway calls with retry (exponential backoff), error normalization, correlation IDs, and `GatewayResult` persistence. Therfore, we want to mock the underlying gateway calls to ensure that our client is properly handling the results, retries, and errors from the gateway.

Rather than mocking the raw HTTP requests, we can mock the gateway methods that the client calls. This allows us to test the client's handling of the gateway's responses and errors without worrying about the specifics of the HTTP requests.

Clients should always return a `GatewayResult` object, so we can use that as a basis for our expectations in the tests. We can also use the `runGatewayResultExpectations()` helper function to ensure that the `GatewayResult` has the expected structure and properties.

Example:

```coldfusion
// static test data that can be used across multiple tests in this spec file
variables._data = {
    "gatewayClass" = "models.domain.gateways.DomainGateway", // needed for runGatewayResultExpectations()
    "clientClass"  = "models.domain.clients.DomainClient", // needed for runGatewayResultExpectations()
    "gatewayResults": {
        "getData": { 
            "200": deSerializeJSON( fileRead( expandPath( "/fixtures/gateways/domain/apiCall-getData-200.json" ) ) ) 
        }
    }
};

describe( "Client Name", function() {

    beforeEach( function( currentSpec ) {
        // init the model and autowire it so we can mock the gateway calls
        variables.model = createMock( "models.domain.clients.DomainClient" );
        variables.model.init();
        getWireBox().autowire( variables.model );

        // Create a mock gateway and inject it into the model
        variables.mockGateway = createStub( extends="models.domain.gateways.DomainGateway" );
        variables.model.$property( "gateway", "variables", variables.mockGateway );
    } );

    it( "can delegate getData to the gateway", function() {

        // mock the gateway's getData method to return a successful result
        mockGateway.$( "getData", _data.gatewayResults.getData[ "200" ] );

        var result = model.getData( { ... } );

        runGatewayResultExpectations( result );

        expect( result ).toBeInstanceOf( "GatewayResult" );
        expect( result.isSuccess() ).toBeTrue();
        expect( mockGateway.$count( "getData" ) ).toBe( 1 );

    } );

} );
```

## Integration Tests

Integration tests are used to test the full request lifecyle of the app. In this app's case it's usually meant to test the REST handlers located in the `handlers` directory. These tests emulate real HTTP requests to the app and ensure that the responses are as expected. 

Integration tests should extend from `BaseIntegrationSpec` which provides helper methods and properties for making HTTP requests, handling authentication, database transactions (with rollbacks), etc.

It is very important that each test execute `setup()` before running otherwise everything will look like the same request.

Example:

```coldfusion
beforeEach( function( currentSpec ) {
    // Setup as a new ColdBox request, VERY IMPORTANT. ELSE EVERYTHING LOOKS LIKE THE SAME REQUEST.
    setup();
    // Authenticate the request (Authorization: Bearer …)
    authenticate();
} );
```

## Quick Entity Unit Tests

We treat Quick ORM entities as a self-contained "unit". Since they are transients, we don't have to worry about state leaking between tests, so we can use `getInstance()` to instantiate them.  If we need to mock anything, we can use `prepareMock()` around `getInstance()` to prep the entity for mocking.

Example:

```coldfusion
beforeEach( function( currentSpec ) {
    // instantiate and prep entity for mocking
    variables.model = prepareMock( getInstance( "MyEntity" ) );
} );
```

## Mocking Notes

Mocking is done via MockBox. Below are a few notes for quick reference when writing tests that require mocking:

When using:

- `createStub()`: you can specify the `extends` argument to create a stub that extends a specific class. Useful when we need the same methods or class signature as the original.

## Looping over collections in tests

When looping over collections in tests, it's important to ensure that the loop is properly scoped and that any variables used within the loop are passed in the data argument. This is because the loop variable will not be properly scoped within the test function, and you may end up with unexpected results.

### WRONG:
```coldfusion
for ( var item in variables.collection ) {
    it( "it works with #item#", function() {
        expect( item ).toBe( "something" ); // this will not be the item you expect!
    } );
}
```

### CORRECT:
```coldfusion
for ( var item in variables.collection ) {
    it( 
        title = "it works with #item#", 
        data = { "item": item }, // pass item as data to ensure proper scoping
        body = function( data ) {
        expect( data.item ).toBe( "something" ); // this works because we are accessing item through the data argument, which is properly scoped for each iteration of the loop
    } );
}
```

## Bare Minimum Unit Test Example

```coldfusion
component extends="tests.resources.BaseUnitSpec" {
    function run(){
        describe( "A [model name]", function(){

            beforeEach( function() {
                variables.model = getInstance( "[model]" );
            } );

            it( "can be created", function(){
                expect( model ).toBeComponent();
                expect( model ).toBeInstanceOf( [model] );
            });
        } );
    }
}```

