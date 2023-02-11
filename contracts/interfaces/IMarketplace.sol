// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMarketplace {
    struct Item {
        address tokenAddress;
        uint256 deadline;
        bytes tokenInfo;
        bytes message;
        bytes signature;
    }

    struct Payment {
        uint256 usdPrice;
        address[] payments;
    }

    struct PaymentOption {
        address token;
        uint256 amount;
        uint256 deadline;
        bytes signature;
    }

    struct Sale {
        address taker;
        Item item;
        Payment payments;
    }

    struct Order {
        address maker;
        Sale sale;
        PaymentOption option;
    }

    function buyLazyMint(Order calldata order_) external payable;

    event Redeemed(
        address indexed buyer,
        address indexed seller,
        bytes tokenInfo
    );

    event NativeTransfered(
        address indexed from,
        address indexed to,
        bool indexed isRefund,
        uint256 amount
    );
}
