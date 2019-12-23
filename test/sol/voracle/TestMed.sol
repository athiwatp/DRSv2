pragma solidity ^0.5.0;

import "../../../contracts/modules/voracle/Med.sol";
import "../mocks/MockIPRS.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";

contract TestMed {
    MockIPRS public mockIPRS1;
    MockIPRS public mockIPRS2;

    constructor() public {
        mockIPRS1 = new MockIPRS(100);
        mockIPRS2 = new MockIPRS(120);
    }

    function testInitialize() public {
        Med med = Med(DeployedAddresses.Med());
        med.initialize(address(this), "VELOUSD");
        Assert.equal(med.pair(), "VELOUSD", "pair must be VELOUSD");
    }

    function testGetWhenPriceIsLessThanZero() public {
        Med med = Med(DeployedAddresses.Med());

        (bool r, ) = address(med).call(abi.encodePacked(med.get.selector));

        Assert.equal(r, false, "med.get() must throw error");
    }

    function testGetWithErrorWhenPriceIsLessThanZero() public {
        Med med = Med(DeployedAddresses.Med());

        (uint256 price, bool isErr) = med.getWithError();

        Assert.equal(price, 0, "med.getWithError() must return price = 0");
        Assert.equal(isErr, true, "med.getWithError() must return isErr = true");
    }

    function testSetMinFedPrices() public {
        Med med = Med(DeployedAddresses.Med());
        med.setMinFedPrices(2);
        Assert.equal(uint(med.minFedPrices()), uint(2), "minFedPrices must be 2");

        med.setMinFedPrices(1);
        Assert.equal(uint(med.minFedPrices()), uint(1), "minFedPrices must be 1");
    }

    function testAddFeeder() public {
        Med med = Med(DeployedAddresses.Med());

        med.addFeeder(address(mockIPRS1));
        med.addFeeder(address(mockIPRS2));

        address[] memory feeders = med.getFeeders();

        Assert.equal(feeders[0], address(mockIPRS2), "feeder[0] must be address(mockIPRS2)");
        Assert.equal(feeders[1], address(mockIPRS1), "feeder[1] must be address(mockIPRS1)");
        Assert.equal(feeders.length, 2, "feeders.length must be 2");
    }

    function testRemoveFeeder() public {
        Med med = Med(DeployedAddresses.Med());

        med.removeFeeder(address(mockIPRS1), address(mockIPRS2));
        med.removeFeeder(address(mockIPRS2), address(1));

        address[] memory feeders = med.getFeeders();

        Assert.equal(feeders.length, 0, "feeders.length must be 0");
    }

    function testComputeOddFeeder() public {
        Med med = Med(DeployedAddresses.Med());

        med.addFeeder(address(mockIPRS1));
        (uint256 median, bool isErr) = med.compute();

        Assert.equal(median, 100, "median must be 100");
        Assert.equal(isErr, false, "isErr must be false");

        med.removeFeeder(address(mockIPRS1), address(1));
        address[] memory feeders = med.getFeeders();

        Assert.equal(feeders.length, 0, "feeders.length must be 0");
    }

    function testComputeEvenFeeder() public {
        Med med = Med(DeployedAddresses.Med());

        testAddFeeder();

        (uint256 median, bool isErr) = med.compute();

        Assert.equal(median, 110, "median must be 110");
        Assert.equal(isErr, false, "isErr must be false");

        testRemoveFeeder();
    }

    function testPost() public {
        Med med = Med(DeployedAddresses.Med());

        med.addFeeder(address(mockIPRS1));
        med.addFeeder(address(mockIPRS2));

        mockIPRS1.set(130);

        med.post();

        Assert.equal(med.price(), 125, "med.price() must be 125");

        testRemoveFeeder();
    }

    function testGet() public {
        Med med = Med(DeployedAddresses.Med());

        uint256 medianPrice = med.get();

        Assert.equal(medianPrice, 125, "med.get() should return 125");
    }

    function testGetWithError() public {
        Med med = Med(DeployedAddresses.Med());

        (uint256 medianPrice, bool isErr) = med.getWithError();

        Assert.equal(medianPrice, 125, "med.getWithError() should return 125");
        Assert.equal(isErr, false, "med.getWithError() should return false");
    }

    function testNoOtherCanCallSet() public {
        Med med = Med(DeployedAddresses.Med());

        (bool r, ) = address(med).call(abi.encodePacked(med.set.selector));

        Assert.equal(r, false, "med.set(...) must throw error");
    }

    function testDisable() public {
        Med med = Med(DeployedAddresses.Med());
        med.disable();
        Assert.equal(med.active(), false, "active must be false");
    }

    function testGetWithErrorWhenActiveIsFalse() public {
        Med med = Med(DeployedAddresses.Med());

        (uint256 price, bool isErr) = med.getWithError();

        Assert.equal(price, 125, "med.getWithError() must return price = 125");
        Assert.equal(isErr, true, "med.getWithError() must return isErr = true");
    }
}