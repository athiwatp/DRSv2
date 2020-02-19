package vclient

import (
	"context"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/velo-protocol/DRSv2/go/abi"
	"github.com/velo-protocol/DRSv2/go/constants"
	"github.com/velo-protocol/DRSv2/go/libs/utils"
)

type RebalanceInput struct {
	// add more if need to add more features.
}

type RebalanceOutput struct {
	Message  string
	Txs      []*types.Transaction
	Receipts []*types.Receipt
	Events   []RebalanceEvent
}

type RebalanceEvent struct {
	AssetCode           string
	CollateralAssetCode string
	RequiredAmount      string
	PresentAmount       string
	Raw                 *types.Log
}

func (i *RebalanceEvent) ToEventOutput(eventAbi *vabi.DigitalReserveSystemRebalance) {
	i.AssetCode = eventAbi.AssetCode
	i.CollateralAssetCode = utils.Byte32ToString(eventAbi.CollateralAssetCode)
	i.RequiredAmount = utils.AmountToString(eventAbi.RequiredAmount)
	i.PresentAmount = utils.AmountToString(eventAbi.PresentAmount)
	i.Raw = &eventAbi.Raw
}

func (c *Client) Rebalance(ctx context.Context, input *RebalanceInput) (*RebalanceOutput, error) {
	rebalanceOutput := &RebalanceOutput{
		Message:  "rebalance process completed.",
		Txs:      []*types.Transaction{},
		Receipts: []*types.Receipt{},
	}

	opt := bind.NewKeyedTransactor(&c.privateKey)
	opt.GasLimit = constants.GasLimit

	// 1. get count all StableCredit in Heart Contract
	stableCreditSize, err := c.contract.heart.GetStableCreditCount(nil)
	if err != nil {
		return nil, err
	}

	if stableCreditSize == 0 {
		return nil, errors.New("stable credit not found")
	}

	var curStableCreditAddress common.Address
	var curAssetCode *string
	var curStableCreditId *[32]byte
	var prevStableCreditId *[32]byte
	// 2. loop StableCredit from stableCreditSize
	for i := 0; i < int(stableCreditSize); i++ {
		if i == 0 {
			// 2.1 get recent StableCredit from linklist in Heart Contract
			curStableCreditAddress, err = c.contract.heart.GetRecentStableCredit(nil)
			if err != nil {
				return nil, err
			}
		} else {
			// 2.2 get next StableCredit for each stableCreditId
			curStableCreditAddress, err = c.contract.heart.GetNextStableCredit(nil, *prevStableCreditId)
			if err != nil {
				return nil, err
			}
		}

		// 2.3 get stable credit contract for get asset code each stable credit address
		curAssetCode, curStableCreditId, err = c.txHelper.StableCreditAssetCode(curStableCreditAddress)
		if err != nil {
			return nil, err
		}

		tx, err := c.contract.drs.Rebalance(
			opt,
			*curAssetCode,
		)
		if err != nil {
			return nil, err
		}

		receipt, err := c.txHelper.ConfirmTx(ctx, tx)
		if err != nil {
			return nil, err
		}

		eventLog := utils.FindLogEvent(receipt.Logs, "Rebalance(string,bytes32,uint256,uint256)")
		if eventLog == nil {
			return nil, errors.Errorf("cannot find rebalance event from transaction receipt %s", tx.Hash().String())
		}

		eventAbi, err := c.txHelper.ExtractRebalanceEvent("Rebalance", eventLog)
		if err != nil {
			return nil, err
		}
		event := new(RebalanceEvent)
		event.ToEventOutput(eventAbi)

		// Append to rebalanceOutput Txs, Receipts, and Results
		rebalanceOutput.Txs = append(rebalanceOutput.Txs, tx)
		rebalanceOutput.Receipts = append(rebalanceOutput.Receipts, receipt)
		rebalanceOutput.Events = append(rebalanceOutput.Events, *event)

		// keep the recent of prevStableCreditAddress from loop
		prevStableCreditId = curStableCreditId
	}

	return rebalanceOutput, nil
}
