
# =============================================================
# $Id: audit.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUDIT {

asSetAct ADMIN::AUDIT::DoAuditBack [namespace code do_audit_back]
asSetAct ADMIN::AUDIT::GoAudit [namespace code go_audit]

variable AUDIT_INFO

#
# ----------------------------------------------------------------------------
# Auditing queries
# ----------------------------------------------------------------------------
#

#
# tab -     the audit table name
# col -     the primary key of the 'base' table (used with 'id' to get all audit entries)
# id -      the name of the var in the form submitted that holds a unique value of 'col'
# hidden -  any hidden elements you want bound for the Back action
# action -  the 'Back' action (when a person clicks back on the audit page)
# skip   -  any audit column names you wish to skip displaying
# admusr -
#
set AUDIT_INFO(Class,tab)       tEvClass_Aud
set AUDIT_INFO(Class,col)       ev_class_id
set AUDIT_INFO(Class,id)        ClassId
set AUDIT_INFO(Class,hidden)    [list ClassId]
set AUDIT_INFO(Class,action)    ADMIN::CLASS::go_class
set AUDIT_INFO(Class,skip)      [list aud_order\
                                      ev_class_id\
                                      user_id\
                                      category\
                                      cr_date]
set AUDIT_INFO(Class,admusr)    [list aud_id]

set AUDIT_INFO(Coupon,tab)       tCoupon_Aud
set AUDIT_INFO(Coupon,col)       coupon_id
set AUDIT_INFO(Coupon,id)        CouponId
set AUDIT_INFO(Coupon,hidden)    [list ClassId CouponId Category]
set AUDIT_INFO(Coupon,action)    ADMIN::COUPON::go_coupon
set AUDIT_INFO(Coupon,skip)      [list aud_order\
                                       ev_class_id\
                                       user_id\
                                       coupon_id\
                                       cr_date]
set AUDIT_INFO(Coupon,admusr)    [list aud_id]

set AUDIT_INFO(Type,tab)        tEvType_Aud
set AUDIT_INFO(Type,col)        ev_type_id
set AUDIT_INFO(Type,id)         TypeId
set AUDIT_INFO(Type,hidden)     [list ClassId TypeId]
set AUDIT_INFO(Type,action)     ADMIN::TYPE::go_type
set AUDIT_INFO(Type,skip)       [list aud_order\
                                      ev_class_id\
                                      user_id\
                                      ev_type_id\
                                      cr_date]
set AUDIT_INFO(Type,admusr)     [list aud_id]

set AUDIT_INFO(MktGrp,tab)      tEvOcGrp_Aud
set AUDIT_INFO(MktGrp,col)      ev_oc_grp_id
set AUDIT_INFO(MktGrp,id)       MktGrpId
set AUDIT_INFO(MktGrp,hidden)   [list ClassId TypeId MktGrpId]
set AUDIT_INFO(MktGrp,action)   ADMIN::MKT_GRP::go_mkt_grp
set AUDIT_INFO(MktGrp,skip)     [list aud_order\
                                      ev_class_id\
                                      user_id\
                                      ev_type_id\
                                      cr_date]
set AUDIT_INFO(MktGrp,admusr)   [list aud_id]

set AUDIT_INFO(IxMktGrp,tab)    tfMktGrp_Aud
set AUDIT_INFO(IxMktGrp,col)    f_mkt_grp_id
set AUDIT_INFO(IxMktGrp,id)     MktGrpId
set AUDIT_INFO(IxMktGrp,hidden) [list ClassId TypeId MktGrpId]
set AUDIT_INFO(IxMktGrp,action) ADMIN::IX_MKT_GRP::go_ix_mkt_grp
set AUDIT_INFO(IxMktGrp,skip)   [list aud_order\
                                      user_id\
                                      ev_type_id\
                                      cr_date]
set AUDIT_INFO(IxMktGrp,admusr) [list aud_id]

set AUDIT_INFO(Ev,tab)          tEv_Aud
set AUDIT_INFO(Ev,col)          ev_id
set AUDIT_INFO(Ev,id)           EvId
set AUDIT_INFO(Ev,hidden)       [list TypeId EvId]
set AUDIT_INFO(Ev,action)       ADMIN::EVENT::go_ev
set AUDIT_INFO(Ev,skip)         [list aud_order\
                                      ev_id\
                                      user_id\
                                      ev_type_id\
                                      cr_date]
set AUDIT_INFO(Ev,admusr)       [list aud_id aux_user_id]

set AUDIT_INFO(EvMkt,tab)       tEvMkt_Aud
set AUDIT_INFO(EvMkt,col)       ev_mkt_id
set AUDIT_INFO(EvMkt,id)        MktId
set AUDIT_INFO(EvMkt,hidden)    [list TypeId EvId MktId]
set AUDIT_INFO(EvMkt,action)    ADMIN::MARKET::go_mkt
set AUDIT_INFO(EvMkt,skip)      [list aud_order\
                                      ev_mkt_id\
                                      user_id\
                                      ev_id\
                                      ev_oc_grp_id\
                                      cr_date]
set AUDIT_INFO(EvMkt,admusr)    [list aud_id]

set AUDIT_INFO(EvIxMkt,tab)     tfMkt_Aud
set AUDIT_INFO(EvIxMkt,col)     f_mkt_id
set AUDIT_INFO(EvIxMkt,id)      IxMktId
set AUDIT_INFO(EvIxMkt,hidden)  [list IxMktId]
set AUDIT_INFO(EvIxMkt,action)  ADMIN::IXMARKET::go_ix_mkt
set AUDIT_INFO(EvIxMkt,skip)    [list aud_order\
                                      f_mkt_id\
                                      user_id\
                                      ev_id\
                                      f_mkt_grp_id\
                                      cr_date]
set AUDIT_INFO(EvIxMkt,admusr)  [list aud_id]

set AUDIT_INFO(EvOcVariant,tab)       tEvOcVariant_AUD
set AUDIT_INFO(EvOcVariant,col)       ev_mkt_id
set AUDIT_INFO(EvOcVariant,id)        MktId
set AUDIT_INFO(EvOcVariant,hidden)    [list MktId]
set AUDIT_INFO(EvOcVariant,action)    ADMIN::MARKET::go_mkt
set AUDIT_INFO(EvOcVariant,skip)      [list]
set AUDIT_INFO(EvOcVariant,admusr)    [list aud_id]

set AUDIT_INFO(EvOcVariantByOc,tab)       tEvOcVariant_AUD
set AUDIT_INFO(EvOcVariantByOc,col)       ev_oc_id
set AUDIT_INFO(EvOcVariantByOc,id)        OcId
set AUDIT_INFO(EvOcVariantByOc,hidden)    [list OcId]
set AUDIT_INFO(EvOcVariantByOc,action)    ADMIN::SELN::go_oc
set AUDIT_INFO(EvOcVariantByOc,skip)      [list]
set AUDIT_INFO(EvOcVariantByOc,admusr)    [list aud_id]

set AUDIT_INFO(EvOc,tab)        tEvOc_Aud
set AUDIT_INFO(EvOc,col)        ev_oc_id
set AUDIT_INFO(EvOc,id)         OcId
set AUDIT_INFO(EvOc,hidden)     [list MktId OcId]
set AUDIT_INFO(EvOc,action)     ADMIN::SELN::go_oc
set AUDIT_INFO(EvOc,skip)       [list aud_order\
                                      ev_oc_id\
                                      user_id\
                                      ev_mkt_id\
                                      ev_id\
                                      cr_date]
set AUDIT_INFO(EvOc,admusr)     [list aud_id]

set AUDIT_INFO(Pmt,tab)         tAcctPayment_Aud
set AUDIT_INFO(Pmt,col)         ref_no
set AUDIT_INFO(Pmt,id)          RefNo
set AUDIT_INFO(Pmt,hidden)      [list RefNo]
set AUDIT_INFO(Pmt,action)      ADMIN::PMT::go_pmt
set AUDIT_INFO(Pmt,skip)        [list aud_order ref_no]
set AUDIT_INFO(EvOc,admusr)     [list aud_id]

set AUDIT_INFO(PM_cc,tab)       tCPMCC_Aud
set AUDIT_INFO(PM_cc,col)       enc_card_no
set AUDIT_INFO(PM_cc,id)        enc_card_no
set AUDIT_INFO(PM_cc,hidden)    [list cpm_id pay_mthd CustId]
set AUDIT_INFO(PM_cc,action)    ADMIN::PMT::go_pay_mthd_auth
set AUDIT_INFO(PM_cc,skip)      [list]
set AUDIT_INFO(PM_cc,admusr)    [list aud_id]

set AUDIT_INFO(PM_envoy,tab)       tCPMEnvoy_Aud
set AUDIT_INFO(PM_envoy,col)       cpm_id
set AUDIT_INFO(PM_envoy,id)        cpm_id
set AUDIT_INFO(PM_envoy,hidden)    [list cpm_id pay_mthd CustId]
set AUDIT_INFO(PM_envoy,action)    ADMIN::PMT::go_pay_mthd_auth
set AUDIT_INFO(PM_envoy,skip)      [list cpm_id envoy_key]
set AUDIT_INFO(PM_envoy,admusr)    [list aud_id]

set AUDIT_INFO(Cust,tab)        tCustomer_Aud
set AUDIT_INFO(Cust,col)        cust_id
set AUDIT_INFO(Cust,id)         CustId
set AUDIT_INFO(Cust,hidden)     [list CustId]
set AUDIT_INFO(Cust,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(Cust,skip)       [list aud_order ref_no]
set AUDIT_INFO(Cust,admusr)     [list aud_id]

set AUDIT_INFO(CustStake,tab)     tCustStkDetail_Aud
set AUDIT_INFO(CustStake,col)     cust_id
set AUDIT_INFO(CustStake,id)      CustId
set AUDIT_INFO(CustStake,hidden)  [list CustId]
set AUDIT_INFO(CustStake,action)  ADMIN::CUST::go_cust
set AUDIT_INFO(CustStake,skip)    [list aud_order ref_no]
set AUDIT_INFO(CustStake,admusr)  [list aud_id]

set AUDIT_INFO(CustReg,tab)       tCustomerReg_Aud
set AUDIT_INFO(CustReg,col)       cust_id
set AUDIT_INFO(CustReg,id)        CustId
set AUDIT_INFO(CustReg,hidden)    [list CustId]
set AUDIT_INFO(CustReg,action)    ADMIN::CUST::go_cust
set AUDIT_INFO(CustReg,skip)      [list aud_order ref_no]
set AUDIT_INFO(CustReg,admusr)    [list aud_id]

set AUDIT_INFO(CustStopCode,tab)     tCustStopCode_Aud
set AUDIT_INFO(CustStopCode,col)     cust_id
set AUDIT_INFO(CustStopCode,id)      CustId
set AUDIT_INFO(CustStopCode,hidden)  [list CustId]
set AUDIT_INFO(CustStopCode,action)  ADMIN::CUST::do_cust_stop_code
set AUDIT_INFO(CustStopCode,skip)    [list aud_order ref_no]
set AUDIT_INFO(CustStopCode,admusr)  [list aud_id]

set AUDIT_INFO(CustPayMthd,tab)     tCustPayMthd_Aud
set AUDIT_INFO(CustPayMthd,col)     cpm_id
set AUDIT_INFO(CustPayMthd,id)      cpm_id
set AUDIT_INFO(CustPayMthd,hidden)  [list cpm_id pay_mthd CustId]
set AUDIT_INFO(CustPayMthd,action)  ADMIN::PMT::go_pay_mthd_auth
set AUDIT_INFO(CustPayMthd,skip)    [list go_pay_mthd_auth]
set AUDIT_INFO(CustPayMthd,admusr)  [list aud_id]

set AUDIT_INFO(Acct,tab)        tAcct_Aud
set AUDIT_INFO(Acct,col)        acct_id
set AUDIT_INFO(Acct,id)         AcctId
set AUDIT_INFO(Acct,hidden)     [list CustId]
set AUDIT_INFO(Acct,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(Acct,skip)       [list aud_order ref_no]
set AUDIT_INFO(Acct,admusr)     [list aud_id]

set AUDIT_INFO(StmtAud,tab)        tAcctStmt_Aud
set AUDIT_INFO(StmtAud,col)        acct_id
set AUDIT_INFO(StmtAud,id)         AcctId
set AUDIT_INFO(StmtAud,hidden)     [list CustId]
set AUDIT_INFO(StmtAud,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(StmtAud,skip)       [list aud_order ref_no]
set AUDIT_INFO(StmtAud,admusr)     [list aud_id]

set AUDIT_INFO(CustomerFlag,tab)        tCustomerFlag_Aud
set AUDIT_INFO(CustomerFlag,col)        cust_id
set AUDIT_INFO(CustomerFlag,id)         CustId
set AUDIT_INFO(CustomerFlag,hidden)     [list CustId]
set AUDIT_INFO(CustomerFlag,action)     ADMIN::CUST::go_cust_flags
set AUDIT_INFO(CustomerFlag,skip)       [list]
set AUDIT_INFO(CustomerFlag,admusr)     [list aud_id]

set AUDIT_INFO(CustomerFlagSingle,tab)        tCustomerFlag_Aud
set AUDIT_INFO(CustomerFlagSingle,col)        cust_id
set AUDIT_INFO(CustomerFlagSingle,id)         CustId
set AUDIT_INFO(CustomerFlagSingle,hidden)     [list CustId]
set AUDIT_INFO(CustomerFlagSingle,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(CustomerFlagSingle,skip)       [list]
set AUDIT_INFO(CustomerFlagSingle,admusr)     [list aud_id]

set AUDIT_INFO(CustLimits,tab)        tCustLimits_aud
set AUDIT_INFO(CustLimits,col)        cust_id
set AUDIT_INFO(CustLimits,id)         CustId
set AUDIT_INFO(CustLimits,hidden)     [list CustId]
set AUDIT_INFO(CustLimits,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(CustLimits,skip)       [list]
set AUDIT_INFO(CustLimits,admusr)     [list aud_id]

set AUDIT_INFO(CustomerMsg,tab)        tCustomerMsg_Aud
set AUDIT_INFO(CustomerMsg,col)        cust_id
set AUDIT_INFO(CustomerMsg,id)         CustId
set AUDIT_INFO(CustomerMsg,hidden)     [list CustId]
set AUDIT_INFO(CustomerMsg,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(CustomerMsg,skip)       [list]
set AUDIT_INFO(CustomerMsg,admusr)     [list aud_id]

set AUDIT_INFO(XGame,tab)        tXGame_Aud
set AUDIT_INFO(XGame,col)        xgame_id
set AUDIT_INFO(XGame,id)         xgame_id
set AUDIT_INFO(XGame,hidden)     [list xgame_id]
set AUDIT_INFO(XGame,action)     H_GoEditGame
set AUDIT_INFO(XGame,skip)       [list]
set AUDIT_INFO(XGame,admusr)     [list aud_id]

set AUDIT_INFO(Control,tab)        tControl_Aud
set AUDIT_INFO(Control,col)        {}
set AUDIT_INFO(Control,id)         {}
set AUDIT_INFO(Control,hidden)     {}
set AUDIT_INFO(Control,action)     ADMIN::CONTROL::go_control
set AUDIT_INFO(Control,skip)       [list]
set AUDIT_INFO(Control,admusr)     [list aud_id]

set AUDIT_INFO(ExtId,tab)        tExtCust_AUD
set AUDIT_INFO(ExtId,col)        cust_id
set AUDIT_INFO(ExtId,id)         CustId
set AUDIT_INFO(ExtId,hidden)     [list CustId]
set AUDIT_INFO(ExtId,action)     ADMIN::CUST::go_cust
set AUDIT_INFO(ExtId,skip)       [list aud_order ref_no]
set AUDIT_INFO(ExtId,admusr)     [list aud_id]

set AUDIT_INFO(CustNotice,tab)        tCustNotice_Aud
set AUDIT_INFO(CustNotice,col)        ntc_id
set AUDIT_INFO(CustNotice,id)         ntc_id
set AUDIT_INFO(CustNotice,hidden)     ntc_id
set AUDIT_INFO(CustNotice,action)     ADMIN::CUST::NOTICE::show
set AUDIT_INFO(CustNotice,skip)       [list]
set AUDIT_INFO(CustNotice,admusr)     [list aud_id]

set AUDIT_INFO(Vendor,tab)        tBetcardVendor_AUD
set AUDIT_INFO(Vendor,col)        vendor_id
set AUDIT_INFO(Vendor,id)         vendor_id
set AUDIT_INFO(Vendor,hidden)     [list vendor_id]
set AUDIT_INFO(Vendor,action)     ADMIN::BETCARD::go_vendor
set AUDIT_INFO(Vendor,skip)       [list]
set AUDIT_INFO(Vendor,admusr)     [list aud_id]

set AUDIT_INFO(NewsHigh,tab)        tNews_AUD
set AUDIT_INFO(NewsHigh,col)        news_id
set AUDIT_INFO(NewsHigh,id)         news_id
set AUDIT_INFO(NewsHigh,hidden)     [list news_id]
set AUDIT_INFO(NewsHigh,action)     ADMIN::NEWS::go_news_highlight
set AUDIT_INFO(NewsHigh,skip)       [list]
set AUDIT_INFO(NewsHigh,admusr)     [list aud_id]

set AUDIT_INFO(ToteTypeLink,tab)      tToteTypeLink_AUD
set AUDIT_INFO(ToteTypeLink,col)      ev_type_id_tote
set AUDIT_INFO(ToteTypeLink,id)       ev_type_id_tote
set AUDIT_INFO(ToteTypeLink,hidden)   [list]
set AUDIT_INFO(ToteTypeLink,action)   ADMIN::TOTE::go_type_links
set AUDIT_INFO(ToteTypeLink,skip)     [list]
set AUDIT_INFO(ToteTypeLink,admusr)   [list aud_id]

set AUDIT_INFO(ToteEvLink,tab)        tToteEvLink_AUD
set AUDIT_INFO(ToteEvLink,col)        ev_id_tote
set AUDIT_INFO(ToteEvLink,id)         ev_id_tote
set AUDIT_INFO(ToteEvLink,hidden)     [list]
set AUDIT_INFO(ToteEvLink,action)     ADMIN::TOTE::go_ev_links
set AUDIT_INFO(ToteEvLink,skip)       [list]
set AUDIT_INFO(ToteEvLink,admusr)     [list aud_id]

set AUDIT_INFO(ManBet,tab)            tManOBet_Aud
set AUDIT_INFO(ManBet,col)            bet_id
set AUDIT_INFO(ManBet,id)             BetId
set AUDIT_INFO(ManBet,hidden)         [list BetId]
set AUDIT_INFO(ManBet,action)         ADMIN::BET::go_bet_receipt
set AUDIT_INFO(ManBet,skip)           [list aud_order]
set AUDIT_INFO(ManBet,admusr)         [list aud_id]

# audit values for the affiliate table
set AUDIT_INFO(Aff,tab)           taffiliate_aud
set AUDIT_INFO(Aff,col)           aff_id
set AUDIT_INFO(Aff,id)            AffId
set AUDIT_INFO(Aff,hidden)        [list AffId]
set AUDIT_INFO(Aff,action)        ADMIN::AFF::go_aff
set AUDIT_INFO(Aff,skip)          [list]
set AUDIT_INFO(Aff,admusr)        [list aud_id]

# audit values for the affiliate group table
set AUDIT_INFO(AffGrp,tab)        taffiliategrp_aud
set AUDIT_INFO(AffGrp,col)        aff_grp_id
set AUDIT_INFO(AffGrp,id)         AffGrpId
set AUDIT_INFO(AffGrp,hidden)     [list AffGrpId]
set AUDIT_INFO(AffGrp,action)     ADMIN::AFF::go_aff_grp
set AUDIT_INFO(AffGrp,skip)       [list]
set AUDIT_INFO(AffGrp,admusr)     [list aud_id]

# audit values for the affiliate program table
set AUDIT_INFO(BeFreeAffPrg,tab)    taffprogram_aud
set AUDIT_INFO(BeFreeAffPrg,col)    source_id
set AUDIT_INFO(BeFreeAffPrg,id)     source_id
set AUDIT_INFO(BeFreeAffPrg,hidden) [list source_id]
set AUDIT_INFO(BeFreeAffPrg,action) ADMIN::AFF::go_befree_affprog
set AUDIT_INFO(BeFreeAffPrg,skip)   [list]
set AUDIT_INFO(BeFreeAffPrg,admusr) [list aud_id]

# audit values for the program table
set AUDIT_INFO(BeFreePrg,tab)       tprogram_aud
set AUDIT_INFO(BeFreePrg,col)       prog_id
set AUDIT_INFO(BeFreePrg,id)        prog_id
set AUDIT_INFO(BeFreePrg,hidden)    [list prog_id]
set AUDIT_INFO(BeFreePrg,action)    ADMIN::AFF::go_befree_program
set AUDIT_INFO(BeFreePrg,skip)      [list]
set AUDIT_INFO(BeFreePrg,admusr)    [list aud_id]

set AUDIT_INFO(CPMRule,tab)         tCPMRule_AUD
set AUDIT_INFO(CPMRule,col)         rule_id
set AUDIT_INFO(CPMRule,id)          rule_id
set AUDIT_INFO(CPMRule,hidden)      [list RuleId CPMRuleType back_action this_action]
set AUDIT_INFO(CPMRule,action)      ADMIN::CPM_RULES::go_cpm_rule_edit
set AUDIT_INFO(CPMRule,skip)        [list]
set AUDIT_INFO(CPMRule,admusr)      [list aud_id]

set AUDIT_INFO(CPMOp,tab)           tCPMOp_AUD
set AUDIT_INFO(CPMOp,col)           op_id
set AUDIT_INFO(CPMOp,id)            op_id
set AUDIT_INFO(CPMOp,hidden)        [list OpId back_action this_action]
set AUDIT_INFO(CPMOp,action)        ADMIN::CPM_RULES::go_cpm_op_edit
set AUDIT_INFO(CPMOp,skip)          [list]
set AUDIT_INFO(CPMOp,admusr)        [list aud_id]

# audit values for the bir index table
set AUDIT_INFO(tMktBirIdx,tab)           tMktBirIdx_AUD
set AUDIT_INFO(tMktBirIdx,col)           ev_mkt_id
set AUDIT_INFO(tMktBirIdx,id)            MktId
set AUDIT_INFO(tMktBirIdx,hidden)        [list MktId]
set AUDIT_INFO(tMktBirIdx,action)        ADMIN::SELN::go_ocs_res
set AUDIT_INFO(tMktBirIdx,skip)          [list]
set AUDIT_INFO(tMktBirIdx,admusr)        [list aud_id]

# audit values for the bir index table
set AUDIT_INFO(tMktBirIdxRes,tab)           tMktBirIdxRes_AUD
set AUDIT_INFO(tMktBirIdxRes,col)           mkt_bir_idx
set AUDIT_INFO(tMktBirIdxRes,id)            AudMktIdx
set AUDIT_INFO(tMktBirIdxRes,hidden)        [list MktId]
set AUDIT_INFO(tMktBirIdxRes,action)        ADMIN::SELN::go_ocs_res
set AUDIT_INFO(tMktBirIdxRes,skip)          [list]
set AUDIT_INFO(tMktBirIdxRes,admusr)        [list aud_id]

# audit values for the txferstatus table
set AUDIT_INFO(tXferStatus,tab)           tXferStatus_AUD
set AUDIT_INFO(tXferStatus,col)           tx_id
set AUDIT_INFO(tXferStatus,id)            tx_id
set AUDIT_INFO(tXferStatus,hidden)        [list tx_id]
set AUDIT_INFO(tXferStatus,action)        ADMIN::CUST::edit_casino_tfrs
set AUDIT_INFO(tXferStatus,skip)          [list]
set AUDIT_INFO(tXferStatus,admusr)        [list aud_id]

# audit values for the cust group table
set AUDIT_INFO(tCustGroup,tab)     tCustGroup_AUD
set AUDIT_INFO(tCustGroup,col)     cust_id
set AUDIT_INFO(tCustGroup,id)      CustId
set AUDIT_INFO(tCustGroup,hidden)  [list CustId]
set AUDIT_INFO(tCustGroup,action)  ADMIN::CUST::go_cust
set AUDIT_INFO(tCustGroup,skip)    [list]
set AUDIT_INFO(tCustGroup,admusr)  [list aud_id]

# audit table for payment methods
set AUDIT_INFO(PayMthd,tab)         tPayMthd_Aud
set AUDIT_INFO(PayMthd,col)         pay_mthd
set AUDIT_INFO(PayMthd,id)          pay_mthd
set AUDIT_INFO(PayMthd,hidden)      [list pay_mthd]
set AUDIT_INFO(PayMthd,action)      ADMIN::PAY_MTHD::go_pay_mthd
set AUDIT_INFO(PayMthd,skip)        [list]
set AUDIT_INFO(PayMthd,admusr)      [list aud_id]


set AUDIT_INFO(StmtRecord,tab)         tStmtRecord_aud
set AUDIT_INFO(StmtRecord,col)         stmt_id
set AUDIT_INFO(StmtRecord,id)          stmt_id
set AUDIT_INFO(StmtRecord,hidden)      [list CustId]
set AUDIT_INFO(StmtRecord,action)      ADMIN::CUST::go_cust_stmt
set AUDIT_INFO(StmtRecord,skip)        [list]
set AUDIT_INFO(StmtRecord,admusr)      [list aud_id]

set AUDIT_INFO(StmtRecordQry,tab)      tStmtRecord_aud
set AUDIT_INFO(StmtRecordQry,col)      stmt_id
set AUDIT_INFO(StmtRecordQry,id)       stmt_id
set AUDIT_INFO(StmtRecordQry,hidden)   [list CustId \
                                             Username \
                                             ignorecase \
                                             AcctNo \
                                             product_filter \
                                             StmtCrDate1 \
                                             StmtCrDate2 \
                                             DateRange]
set AUDIT_INFO(StmtRecordQry,action)   ADMIN::STMT_RCD::do_stmt_rcd_qry
set AUDIT_INFO(StmtRecordQry,skip)     [list]
set AUDIT_INFO(StmtRecordQry,admusr)   [list aud_id]


# audit table for Betfair Orders
if {[OT_CfgGet BF_ACTIVE 0]} {
	set AUDIT_INFO(BetfairOrder,tab)         tBFOrder_Aud
	set AUDIT_INFO(BetfairOrder,col)         bf_order_id
	set AUDIT_INFO(BetfairOrder,id)          BFOrderId
	set AUDIT_INFO(BetfairOrder,hidden)      [list BFOrderId BFBetId BFOrderTypeV BFOrderType]
	set AUDIT_INFO(BetfairOrder,action)      ADMIN::BETFAIR_ORDER::go_bf_seln_order_upd
	set AUDIT_INFO(BetfairOrder,skip)        [list]
	set AUDIT_INFO(BetfairOrder,admusr)      [list aud_id]

	# audit table for Betfair Passbets
	set AUDIT_INFO(BetfairPassbet,tab)         tBFPassBet_Aud
	set AUDIT_INFO(BetfairPassbet,col)         bf_pass_bet_id
	set AUDIT_INFO(BetfairPassbet,id)          BFPassBetId
	set AUDIT_INFO(BetfairPassbet,hidden)      [list BFPassBetId BFBetId BFOrderTypeV BFOrderType]
	set AUDIT_INFO(BetfairPassbet,action)      ADMIN::BETFAIR_PASSBET::go_bf_passbet
	set AUDIT_INFO(BetfairPassbet,skip)        [list]
	set AUDIT_INFO(BetfairPassbet,admusr)      [list aud_id]

	# audit table for Betfair Monitors
	set AUDIT_INFO(BetfairMonitor,tab)         tBFMonitor_Aud
	set AUDIT_INFO(BetfairMonitor,col)         bf_monitor_id
	set AUDIT_INFO(BetfairMonitor,id)          MktBFMonitorId
	set AUDIT_INFO(BetfairMonitor,hidden)      [list TypeId EvId MktId MktBFMonitorId]
	set AUDIT_INFO(BetfairMonitor,action)      ADMIN::MARKET::go_mkt
	set AUDIT_INFO(BetfairMonitor,skip)        [list type queue_num bf_monitor_id ob_id bf_exch_id bf_id bf_parent_id bf_asian_id]
	set AUDIT_INFO(BetfairMonitor,admusr)      [list aud_id]
}

# audit table for payment methods
set AUDIT_INFO(VrfPrflModel,tab)         tVrfPrflModel_aud
set AUDIT_INFO(VrfPrflModel,col)         vrf_prfl_def_id
set AUDIT_INFO(VrfPrflModel,id)          profile_def_id
set AUDIT_INFO(VrfPrflModel,hidden)      [list profile_def_id]
set AUDIT_INFO(VrfPrflModel,action)      ADMIN::VERIFICATION::go_prfl_model
set AUDIT_INFO(VrfPrflModel,skip)        [list]
set AUDIT_INFO(VrfPrflModel,admusr)      [list aud_id]

#are we also auditing external audit tables
if {[OT_CfgGet FUNC_EXT_AUDIT 0]} {
	foreach {
		name
		tab
		col
		id
		hidden
		action
		skip
		admusr
	} [ADMIN::EXT::audit] {
		set AUDIT_INFO(${name},tab)        $tab
		set AUDIT_INFO(${name},col)        $col
		set AUDIT_INFO(${name},id)         $id
		set AUDIT_INFO(${name},hidden)     $hidden
		set AUDIT_INFO(${name},action)     $action
		set AUDIT_INFO(${name},skip)       $skip
		set AUDIT_INFO(${name},admusr)     $admusr
	}

}

set AUDIT_INFO(BanCat,tab)        tCntryBanCat_AUD
set AUDIT_INFO(BanCat,col)        country_code
set AUDIT_INFO(BanCat,id)         CountryCode
set AUDIT_INFO(BanCat,hidden)     [list CountryCode]
set AUDIT_INFO(BanCat,action)     ADMIN::COUNTRY::go_country
set AUDIT_INFO(BanCat,skip)       [list]
set AUDIT_INFO(BanCat,admusr)     [list aud_id]

set AUDIT_INFO(BanOp,tab)        tCntryBanOp_AUD
set AUDIT_INFO(BanOp,col)        country_code
set AUDIT_INFO(BanOp,id)         CountryCode
set AUDIT_INFO(BanOp,hidden)     [list CountryCode]
set AUDIT_INFO(BanOp,action)     ADMIN::COUNTRY::go_country
set AUDIT_INFO(BanOp,skip)       [list]
set AUDIT_INFO(BanOp,admusr)     [list aud_id]

set AUDIT_INFO(Alert,tab)        tAlert_aud
set AUDIT_INFO(Alert,col)        alert_id
set AUDIT_INFO(Alert,id)         AlertId
set AUDIT_INFO(Alert,hidden)     AlertId
set AUDIT_INFO(Alert,action)     ADMIN::ALERTS::go_alert
set AUDIT_INFO(Alert,skip)       [list]
set AUDIT_INFO(Alert,admusr)     [list aud_id]

set AUDIT_INFO(AlertSetting,tab)        tAlertSetting_aud
set AUDIT_INFO(AlertSetting,col)        cust_code
set AUDIT_INFO(AlertSetting,id)         CustCode
set AUDIT_INFO(AlertSetting,hidden)     CustCode
set AUDIT_INFO(AlertSetting,action)     ADMIN::ALERTS::go_setting
set AUDIT_INFO(AlertSetting,skip)       [list]
set AUDIT_INFO(AlertSetting,admusr)     [list aud_id]

set AUDIT_INFO(AlertAcct,tab)        tAlertAcct_aud
set AUDIT_INFO(AlertAcct,col)        acct_id
set AUDIT_INFO(AlertAcct,id)         AcctId
set AUDIT_INFO(AlertAcct,hidden)     [list AcctId CustId]
set AUDIT_INFO(AlertAcct,action)     ADMIN::ALERTS::go_alert_acct
set AUDIT_INFO(AlertAcct,skip)       [list]
set AUDIT_INFO(AlertAcct,admusr)     [list aud_id]

# audit values for dividends table
set AUDIT_INFO(MktDiv,tab)           tDividend_Aud
set AUDIT_INFO(MktDiv,col)           div_id
set AUDIT_INFO(MktDiv,id)            DivId
set AUDIT_INFO(MktDiv,hidden)        [list MktId]
set AUDIT_INFO(MktDiv,action)        ADMIN::MARKET::go_mkt
set AUDIT_INFO(MktDiv,skip)          [list]
set AUDIT_INFO(MktDiv,admusr)        [list aud_id]

set AUDIT_INFO(StmtControl,tab)      tStmtControl_aud
set AUDIT_INFO(StmtControl,col)      acct_type
set AUDIT_INFO(StmtControl,id)       acct_type
set AUDIT_INFO(StmtControl,hidden)   [list acct_type]
set AUDIT_INFO(StmtControl,action)   ADMIN::STMT_CONTROL::go_stmt_control
set AUDIT_INFO(StmtControl,skip)     [list]
set AUDIT_INFO(StmtControl,admusr)   [list aud_id]

set AUDIT_INFO(tPmt,tab)     tPmt_aud
set AUDIT_INFO(tPmt,col)     [list pmt_id]
set AUDIT_INFO(tPmt,id)      [list pmt_id]
set AUDIT_INFO(tPmt,hidden)  [list pmt_id]
set AUDIT_INFO(tPmt,action)  ADMIN::TXN::GPMT::go_pmt
set AUDIT_INFO(tPmt,skip)    {""}
set AUDIT_INFO(tPmt,admusr)  [list aud_id]

set AUDIT_INFO(tPmtCC,tab)     tPmtCC_aud
set AUDIT_INFO(tPmtCC,col)     [list pmt_id]
set AUDIT_INFO(tPmtCC,id)      [list pmt_id]
set AUDIT_INFO(tPmtCC,hidden)  [list pmt_id]
set AUDIT_INFO(tPmtCC,action)  ADMIN::TXN::GPMT::go_pmt
set AUDIT_INFO(tPmtCC,skip)    {""}
set AUDIT_INFO(tPmtCC,admusr)  [list aud_id]

# Audit values for Debt Management
set AUDIT_INFO(CustomerDebt,tab)     tCustomerDebt_Aud
set AUDIT_INFO(CustomerDebt,col)     cust_debt_id
set AUDIT_INFO(CustomerDebt,id)      cust_debt_id
set AUDIT_INFO(CustomerDebt,hidden)  {""}
set AUDIT_INFO(CustomerDebt,action)  ADMIN::DEBT_MANAGEMENT::go_debt_man_sel
set AUDIT_INFO(CustomerDebt,skip)    {""}
set AUDIT_INFO(CustomerDebt,admusr)  [list aud_id]

set AUDIT_INFO(CustDebtData,tab)     tCustDebtData_Aud
set AUDIT_INFO(CustDebtData,col)     cust_id
set AUDIT_INFO(CustDebtData,id)      cust_id
set AUDIT_INFO(CustDebtData,hidden)  [list  debt_diary_id\
											cust_id\
											SubmitName\
											action\
											ReviewDate\
											AcctNo\
											DiaryStatus\
											csort\
											DebtState ]
set AUDIT_INFO(CustDebtData,action)  ADMIN::DEBT_MANAGEMENT::go_update_details
set AUDIT_INFO(CustDebtData,skip)    {""}
set AUDIT_INFO(CustDebtData,admusr)  [list aud_id]

set AUDIT_INFO(DebtDiary,tab)     tDebtDiary_Aud
set AUDIT_INFO(DebtDiary,col)     cust_id
set AUDIT_INFO(DebtDiary,id)      cust_id
set AUDIT_INFO(DebtDiary,hidden)  [list debt_diary_id\
										cust_id\
										SubmitName\
										action\
										ReviewDate\
										AcctNo\
										DiaryStatus\
										csort\
										DebtState ]
set AUDIT_INFO(DebtDiary,action)  ADMIN::DEBT_MANAGEMENT::go_update_details
set AUDIT_INFO(DebtDiary,skip)    {""}
set AUDIT_INFO(DebtDiary,admusr)  [list aud_id]

set AUDIT_INFO(CustIdent,tab)     tCustIdent_Aud
set AUDIT_INFO(CustIdent,col)     cust_id
set AUDIT_INFO(CustIdent,id)      CustId
set AUDIT_INFO(CustIdent,hidden)  CustId
set AUDIT_INFO(CustIdent,action)  ADMIN::CUSTIDENT::H_go_ident
set AUDIT_INFO(CustIdent,skip)    [list passport_ivec nat_id_ivec cc_ivec]
set AUDIT_INFO(CustIdent,admusr)  [list aud_id]

set AUDIT_INFO(PerformStreamMapping,tab)       tVSContentLink_aud
set AUDIT_INFO(PerformStreamMapping,col)       [list ]
set AUDIT_INFO(PerformStreamMapping,id)        [list ]
set AUDIT_INFO(PerformStreamMapping,hidden)    [list days\
                                                     dateStart\
                                                     dateEnd\
                                                     mapped]
set AUDIT_INFO(PerformStreamMapping,action)    ADMIN::PERFORM::goStreamRequest
set AUDIT_INFO(PerformStreamMapping,skip)      [list]
set AUDIT_INFO(PerformStreamMapping,admusr)    [list aud_id]

set AUDIT_INFO(CustSysExcl,tab)     tCustSysExcl_Aud
set AUDIT_INFO(CustSysExcl,col)     cust_id
set AUDIT_INFO(CustSysExcl,id)      CustId
set AUDIT_INFO(CustSysExcl,hidden)  CustId
set AUDIT_INFO(CustSysExcl,action)  ADMIN::CUST::go_chan_sys_exclusions
set AUDIT_INFO(CustSysExcl,skip)    [list]
set AUDIT_INFO(CustSysExcl,admusr)  [list aud_id]

set AUDIT_INFO(CustChanExcl,tab)     tCustChanExcl_Aud
set AUDIT_INFO(CustChanExcl,col)     cust_id
set AUDIT_INFO(CustChanExcl,id)      CustId
set AUDIT_INFO(CustChanExcl,hidden)  CustId
set AUDIT_INFO(CustChanExcl,action)  ADMIN::CUST::go_chan_sys_exclusions
set AUDIT_INFO(CustChanExcl,skip)    [list]
set AUDIT_INFO(CustChanExcl,admusr)  [list aud_id]

set AUDIT_INFO(SearchSynonymID,tab)      tSearchSynonym_AUD
set AUDIT_INFO(SearchSynonymID,col)      synonym_id
set AUDIT_INFO(SearchSynonymID,id)       synonym_id
set AUDIT_INFO(SearchSynonymID,admusr)   [list aud_id]
set AUDIT_INFO(SearchSynonymID,skip)     [list aud_order]
set AUDIT_INFO(SearchSynonymID,hidden)   [list synonym_id\
                                               synonym\
                                               keyword\
                                               lang\
                                               disporder\
                                               crit_keyword\
                                               crit_synonym\
                                               crit_lang]
set AUDIT_INFO(SearchSynonymID,action)   ADMIN::SEARCH::go_synonym

set AUDIT_INFO(SearchPredefinedID,tab)      tSearchPredef_AUD
set AUDIT_INFO(SearchPredefinedID,col)      search_id
set AUDIT_INFO(SearchPredefinedID,id)       search_id
set AUDIT_INFO(SearchPredefinedID,admusr)   [list aud_id]
set AUDIT_INFO(SearchPredefinedID,skip)     [list aud_order]
set AUDIT_INFO(SearchPredefinedID,hidden)   [list search_id\
                                                  keyword\
                                                  link\
                                                  url\
                                                  lang\
                                                  disporder\
                                                  canvas_name\
                                                  crit_keyword\
                                                  crit_lang]
set AUDIT_INFO(SearchPredefinedID,action)   ADMIN::SEARCH::go_predefined

set AUDIT_INFO(SearchSynonymKey,tab)      tSearchSynonym_AUD
set AUDIT_INFO(SearchSynonymKey,col)      keyword
set AUDIT_INFO(SearchSynonymKey,id)       keyword
set AUDIT_INFO(SearchSynonymKey,admusr)   [list aud_id]
set AUDIT_INFO(SearchSynonymKey,skip)     [list aud_order]
set AUDIT_INFO(SearchSynonymKey,hidden)   [list synonym\
                                                keyword\
                                                lang\
                                                crit_keyword\
                                                crit_synonym\
                                                crit_lang]
set AUDIT_INFO(SearchSynonymKey,action)   ADMIN::SEARCH::go_synonym_list

set AUDIT_INFO(SearchPredefinedKey,tab)      tSearchPredef_AUD
set AUDIT_INFO(SearchPredefinedKey,col)      keyword
set AUDIT_INFO(SearchPredefinedKey,id)       keyword
set AUDIT_INFO(SearchPredefinedKey,admusr)   [list aud_id]
set AUDIT_INFO(SearchPredefinedKey,skip)     [list aud_order]
set AUDIT_INFO(SearchPredefinedKey,hidden)   [list keyword\
                                                   lang\
                                                   crit_keyword\
                                                   crit_lang]
set AUDIT_INFO(SearchPredefinedKey,action)   ADMIN::SEARCH::go_predefined_list

set AUDIT_INFO(kycCust,tab)     tKYCCust_aud
set AUDIT_INFO(kycCust,col)     cust_id
set AUDIT_INFO(kycCust,id)      CustId
set AUDIT_INFO(kycCust,hidden)  CustId
set AUDIT_INFO(kycCust,action)  ADMIN::CUST::go_cust
set AUDIT_INFO(kycCust,skip)    [list aud_order\
                                      cust_id\
                                      aud_op]
set AUDIT_INFO(kycCust,admusr)  [list aud_id]

set AUDIT_INFO(ageVerCust,tab)     tVrfCustStatus_aud
set AUDIT_INFO(ageVerCust,col)     cust_id
set AUDIT_INFO(ageVerCust,id)      CustId
set AUDIT_INFO(ageVerCust,hidden)  CustId
set AUDIT_INFO(ageVerCust,action)  ADMIN::CUST::go_cust
set AUDIT_INFO(ageVerCust,skip)    [list aud_order\
                                         cust_id\
                                         vrf_prfl_code\
                                         aud_op\
                                         is_underage\
                                         cust_flag_id]
set AUDIT_INFO(ageVerCust,admusr)  [list aud_id]

# audit values for CardInfo
set AUDIT_INFO(CardInfo,tab)        tCardInfo_AUD
set AUDIT_INFO(CardInfo,col)        card_bin
set AUDIT_INFO(CardInfo,id)         CardBin
set AUDIT_INFO(CardInfo,hidden)     [list CardBin]
set AUDIT_INFO(CardInfo,action)     ADMIN::CARD::go_card_bin
set AUDIT_INFO(CardInfo,skip)       [list aud_order]
set AUDIT_INFO(CardInfo,admusr)     [list aud_id]

# audit values for CardScheme
set AUDIT_INFO(CardScheme,tab)        tCardScheme_AUD
set AUDIT_INFO(CardScheme,col)        bin_lo
set AUDIT_INFO(CardScheme,id)         bin_lo
set AUDIT_INFO(CardScheme,hidden)     [list bin_lo]
set AUDIT_INFO(CardScheme,action)     ADMIN::CARD::go_card_req
set AUDIT_INFO(CardScheme,skip)       [list aud_order]
set AUDIT_INFO(CardScheme,admusr)     [list aud_id]

set AUDIT_INFO(customerToken,tab)     tCustomerToken_aud
set AUDIT_INFO(customerToken,col)     cust_token_id
set AUDIT_INFO(customerToken,id)      cust_token_id
set AUDIT_INFO(customerToken,hidden)  [list CustId\
                                            TokenType\
                                            TokensStatus]
set AUDIT_INFO(customerToken,action)  ADMIN::CUST::go_free_token_list
set AUDIT_INFO(customerToken,skip)    [list aud_order\
                                      cust_id\
                                      token_id\
                                      cust_token_id\
                                      aud_op]
set AUDIT_INFO(customerToken,admusr)  [list aud_id]

set AUDIT_INFO(Xlation,tab)       txlateval_aud
set AUDIT_INFO(Xlation,col)       code_id
set AUDIT_INFO(Xlation,id)        CodeId
set AUDIT_INFO(Xlation,hidden)    [list Lang]
set AUDIT_INFO(Xlation,action)    ADMIN::MSG::go_ml_msg
set AUDIT_INFO(Xlation,skip)      [list aud_order]
set AUDIT_INFO(Xlation,admusr)    [list aud_id]

# audit table for login triggers - update group options
set AUDIT_INFO(loginActGrp,tab)         tLoginActGrp_aud
set AUDIT_INFO(loginActGrp,col)         cust_code
set AUDIT_INFO(loginActGrp,id)          [list cust_code]
set AUDIT_INFO(loginActGrp,hidden)      [list]
set AUDIT_INFO(loginActGrp,action)      ADMIN::LOGINTRIGGERS::go_login_trigger_update_details
set AUDIT_INFO(loginActGrp,skip)        [list]
set AUDIT_INFO(loginActGrp,admusr)      [list aud_id]

# audit table for login triggers - update flag options
set AUDIT_INFO(loginActFlag,tab)         tLoginActFlag_aud
set AUDIT_INFO(loginActFlag,col)         status_flag_tag
set AUDIT_INFO(loginActFlag,id)          [list flag_tag]
set AUDIT_INFO(loginActFlag,hidden)      [list]
set AUDIT_INFO(loginActFlag,action)      ADMIN::LOGINTRIGGERS::go_login_trigger_update_details
set AUDIT_INFO(loginActFlag,skip)        [list]
set AUDIT_INFO(loginActFlag,admusr)      [list aud_id]

# audit table for login triggers - update interval options
set AUDIT_INFO(loginActInt,tab)         tLoginActInt_aud
set AUDIT_INFO(loginActInt,col)         action_id
set AUDIT_INFO(loginActInt,id)          [list action_id]
set AUDIT_INFO(loginActInt,hidden)      [list]
set AUDIT_INFO(loginActInt,action)      ADMIN::LOGINTRIGGERS::go_login_trigger_update_details
set AUDIT_INFO(loginActInt,skip)        [list]
set AUDIT_INFO(loginActInt,admusr)      [list aud_id]

# audit values for Virtual World
set AUDIT_INFO(VirtualWrld,tab)     tVirtualWorldCfg_A
set AUDIT_INFO(VirtualWrld,col)     virtual_world_id
set AUDIT_INFO(VirtualWrld,id)      VrtlWrldAuditId
set AUDIT_INFO(VirtualWrld,hidden)  [list]
set AUDIT_INFO(VirtualWrld,action)  ADMIN::VIRTUALWORLD::go_virtual_world_control
set AUDIT_INFO(VirtualWrld,skip)    [list]
set AUDIT_INFO(VirtualWrld,admusr)  [list aud_id]

set AUDIT_INFO(WHGameURL,tab)      tGameCodeMap_Aud
set AUDIT_INFO(WHGameURL,col)      game_code_id
set AUDIT_INFO(WHGameURL,id)       WHGameCodeId
set AUDIT_INFO(WHGameURL,action)   ADMIN::WHGAMEURLS::go_wh_game_url
set AUDIT_INFO(WHGameURL,admusr)   [list aud_id]
set AUDIT_INFO(WHGameURL,skip)     [list]
set AUDIT_INFO(WHGameURL,hidden)   [list WHGameCodeId]

# audit table for individual fraud check withdrawal limits
set AUDIT_INFO(FraudLimitWtdAcc,tab)       tFraudLimitWtdAcc_
set AUDIT_INFO(FraudLimitWtdAcc,col)       acct_id
set AUDIT_INFO(FraudLimitWtdAcc,id)        AcctId
set AUDIT_INFO(FraudLimitWtdAcc,hidden)    [list CustId]
set AUDIT_INFO(FraudLimitWtdAcc,action)    ADMIN::CUST::go_cust
set AUDIT_INFO(FraudLimitWtdAcc,skip)      [list]
set AUDIT_INFO(FraudLimitWtdAcc,admusr)   [list aud_id]

set AUDIT_INFO(CustRetLim,tab)      tFraudLmtRetAcct_A
set AUDIT_INFO(CustRetLim,col)      acct_id
set AUDIT_INFO(CustRetLim,id)       acctId
set AUDIT_INFO(CustRetLim,action)   ADMIN::CUST::go_cust
set AUDIT_INFO(CustRetLim,admusr)   [list aud_id]
set AUDIT_INFO(CustRetLim,skip)     [list acct_fraud_lmt_id aud_order]
set AUDIT_INFO(CustRetLim,hidden)   [list CustId]

#audit table for countries
set AUDIT_INFO(Country,tab)     tCountry_AUD
set AUDIT_INFO(Country,col)     country_code
set AUDIT_INFO(Country,id)      CountryCode
set AUDIT_INFO(Country,hidden)  [list CountryCode]
set AUDIT_INFO(Country,action)  ADMIN::COUNTRY::go_country_list
set AUDIT_INFO(Country,skip)    [list]
set AUDIT_INFO(Country,admusr)  [list aud_id]

#audit table for ipoints conversion
set AUDIT_INFO(IPoints,tab)     tPtIPointCnv_AUD
set AUDIT_INFO(IPoints,col)     ipoint_cnv_id
set AUDIT_INFO(IPoints,id)      ConversionId
set AUDIT_INFO(IPoints,hidden)  [list SR_username \
                                      SR_upper_username \
                                      SR_acct_no_exact \
                                      SR_acct_no \
                                      SR_date_1 \
                                      SR_date_2 \
                                      SR_date_range \
                                      SR_status \
                                      SR_conversion_id]
set AUDIT_INFO(IPoints,action)  ADMIN::IPOINTS::do_ipoints_query
set AUDIT_INFO(IPoints,skip)    [list]
set AUDIT_INFO(IPoints,admusr)  [list aud_id]

# Audit info for separate user admin ops
set AUDIT_INFO(AdminUserOp,tab)    tAdminUserOp_AUD
set AUDIT_INFO(AdminUserOp,col)    user_id
set AUDIT_INFO(AdminUserOp,id)     UserId
set AUDIT_INFO(AdminUserOp,hidden) [list UserId]
set AUDIT_INFO(AdminUserOp,action) ADMIN::USERS::go_user
set AUDIT_INFO(AdminUserOp,skip)   [list]
set AUDIT_INFO(AdminUserOp,admusr) [list aud_id]

# Audit info for user groups (table name is truncated)
set AUDIT_INFO(AdminUserGroup,tab)    tAdminUserGroup_AU
set AUDIT_INFO(AdminUserGroup,col)    user_id
set AUDIT_INFO(AdminUserGroup,id)     UserId
set AUDIT_INFO(AdminUserGroup,hidden) [list UserId]
set AUDIT_INFO(AdminUserGroup,action) ADMIN::USERS::go_user
set AUDIT_INFO(AdminUserGroup,skip)   [list]
set AUDIT_INFO(AdminUserGroup,admusr) [list aud_id]

# Audit info for group permissions
set AUDIT_INFO(AdminGroupOp,tab)    tAdminGroupOp_AUD
set AUDIT_INFO(AdminGroupOp,col)    group_id
set AUDIT_INFO(AdminGroupOp,id)     GroupId
set AUDIT_INFO(AdminGroupOp,hidden) [list GroupId]
set AUDIT_INFO(AdminGroupOp,action) ADMIN::USERS::go_group
set AUDIT_INFO(AdminGroupOp,skip)   [list]
set AUDIT_INFO(AdminGroupOp,admusr) [list aud_id]

# Audit table for control per channel
set AUDIT_INFO(ControlChannel,tab)        tControlChannel_AU
set AUDIT_INFO(ControlChannel,col)        {}
set AUDIT_INFO(ControlChannel,id)         {}
set AUDIT_INFO(ControlChannel,hidden)     {}
set AUDIT_INFO(ControlChannel,action)     ADMIN::CONTROL::go_control_channel
set AUDIT_INFO(ControlChannel,skip)       [list]
set AUDIT_INFO(ControlChannel,admusr)     [list aud_id]

# Audit table for control per cust group
set AUDIT_INFO(ControlCustGrp,tab)        tControlCustGrp_AU
set AUDIT_INFO(ControlCustGrp,col)        {}
set AUDIT_INFO(ControlCustGrp,id)         {}
set AUDIT_INFO(ControlCustGrp,hidden)     {}
set AUDIT_INFO(ControlCustGrp,action)     ADMIN::CONTROL::go_control_custgrp
set AUDIT_INFO(ControlCustGrp,skip)       [list]
set AUDIT_INFO(ControlCustGrp,admusr)     [list aud_id]

#audit table for ipoints conversion
set AUDIT_INFO(IPoints,tab)     tPtIPointCnv_AUD
set AUDIT_INFO(IPoints,col)     ipoint_cnv_id
set AUDIT_INFO(IPoints,id)      ConversionId
set AUDIT_INFO(IPoints,hidden)  [list SR_username \
                                      SR_upper_username \
                                      SR_acct_no_exact \
                                      SR_acct_no \
                                      SR_date_1 \
                                      SR_date_2 \
                                      SR_date_range \
                                      SR_status \
                                      SR_conversion_id]
set AUDIT_INFO(IPoints,action)  ADMIN::IPOINTS::do_ipoints_query
set AUDIT_INFO(IPoints,skip)    [list]
set AUDIT_INFO(IPoints,admusr)  [list aud_id]

proc go_audit args {

	global DB

	variable AUDIT_INFO

	#
	# First, get all admin user names
	#
	set sql_admusr {
		select
			username,
			user_id
		from
			tAdminUser
	}

	set stmt [inf_prep_sql $DB $sql_admusr]
	set res_admusr [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# Both of these are 'special' users.
	#  The ADMUSR of 0 is for legacy data,
	#  as audits should no longer be created with aud_id of 0
	set ADMUSR(-1) System
	set ADMUSR(0)  System

	set n_rows [db_get_nrows $res_admusr]

	for {set r 0} {$r < $n_rows} {incr r} {
		set user_id  [db_get_col $res_admusr $r user_id]
		set username [db_get_col $res_admusr $r username]
		set ADMUSR($user_id) $username
	}

	db_close $res_admusr


	#
	# Get the audit data
	#
	set what [reqGetArg AuditInfo]

	set table  $AUDIT_INFO($what,tab)
	set column $AUDIT_INFO($what,col)
	set id     [reqGetArg $AUDIT_INFO($what,id)]
	set admusr $AUDIT_INFO($what,admusr)
	set table_Alias t
	set select ${table_Alias}.*
	set secondary_tables ""

	#Hack to order cutomer messages table by sorts
	if {$what == "CustomerMsg"} {
		set order_by "sort asc, aud_order asc"
	} else {
		set order_by "aud_order asc"
	}

	# Iff view auditing for tDividends, filter using tev_mkt_id & div_id
	# as there's a index of (ev_mkt_id,div_id) on tdividend_aud
	switch $what {
		"MktDiv" {
			set ev_mkt_id [reqGetArg [lindex $AUDIT_INFO($what,hidden) 0]]
			set where "where t.ev_mkt_id = $ev_mkt_id and t.$column in ($id)"
		}
		"Control" -
		"PerformStreamMapping" {set where ""}
		"Xlation" {
			set lang [reqGetArg [lindex $AUDIT_INFO($what,hidden) 0]]
			set where "where t.code_id = $id and t.lang = '$lang'"
		}
		default {
			if {$column == ""} {
				set where ""
			} else {
				set where "where t.$column = ?"
			}
		}
	}


	# If tCustSysExcl show the group name as group id is not explanatory
	if {$what == "CustSysExcl"} {
		set select "$select , g.desc"
		set secondary_tables ", tXSysHostGrp g"
		if {$where == ""} {
			set where " where t.group_id = g.group_id"
		} else {
			append where " and t.group_id = g.group_id"
		}
	}

	# If tToteTypeLink, show the name of the event it was linked to
	if {$what == "ToteTypeLink"} {
		set select "$select , et.name as linked_type_name"
		set secondary_tables ", tEvType et"
		if {$where == ""} {
			set where " where t.ev_type_id_norm = et.ev_type_id"
		} else {
			append where " and t.ev_type_id_norm = et.ev_type_id"
		}
	}

	# If tToteEvLink, show the name of the event it was linked to
	if {$what == "ToteEvLink"} {
		set select "$select , e.desc as linked_ev_name"
		set secondary_tables ", tEv e"
		if {$where == ""} {
			set where " where t.ev_id_norm = e.ev_id"
		} else {
			append where " and t.ev_id_norm = e.ev_id"
		}
	}

	# If FraudLimitWtdAcc, show only the limits relevant to the particular account
	if {$what == "FraudLimitWtdAcc"} {
		if {$where == ""} {
			set where "where t.$column = $id"
		} else {
			append where " and t.$column = $id"
		}
	}


	# If tFraudLmtRetAcct, show the system/sport name
	if {$what == "CustRetLim"} {
		set select [subst {$select ,
			case
				when product_area = "ESB" then nvl(ec.name,'---')
				when product_area = "XSYS" then nvl(xh.name,'---')
				else "n/a" end
			as ref_name
		}]
		set secondary_tables ", outer tXSysHost xh, outer tEvCategory ec"
		set ref_name_where_clause "ref_id = xh.system_id and ref_id = ec.ev_category_id"

		if {$where == ""} {
			set where " where $ref_name_where_clause"
		} else {
			append where " and $ref_name_where_clause"
		}
	}

	# If tcountry, where = empty string
	if {$what == "Country"} {
		set where "";
	}

	set sql [subst {
		select
			$select
		from
			$table $table_Alias
			$secondary_tables
		$where
		order by
			$order_by
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $id]
	inf_close_stmt $stmt

	tpSetVar NumRows [set n_rows [db_get_nrows $res]]

	set a_cols [db_get_colnames $res]
	set p_cols [list]

	foreach c $a_cols {
		#
		# Transitional: remove BX Items of BX not configured
		#
		if {![tpGetVar IsBX 0] && [string range $c 0 2] == "bx_"} {
			continue
		}
		if {[lsearch $AUDIT_INFO($what,skip) $c] < 0} {
			lappend p_cols $c
		}
	}

	tpSetVar     NumCols [set n_cols [llength $p_cols]]
	tpBindString NumCols $n_cols

	global DATA HIDDEN

	#
	# Bind data elements
	#
	for {set c 0} {$c < $n_cols} {incr c} {
		set DATA($c,name) [lindex $p_cols $c]
	}

	#
	# Can speed this up - exercise for the reader...
	#
	for {set r 0} {$r < $n_rows} {incr r} {
		if {$r == 0} {
			for {set c 0} {$c < $n_cols} {incr c} {
				set n [lindex $p_cols $c]
				set v [db_get_col $res $r $n]
				# substitute if this is an admin user id
				if {[lsearch -exact $admusr $n] >= 0} {
					if {$what == "CustLimits" && $v == "-1"} {
						set DATA($r,$c,val) "Customer"
						continue
					} elseif {[string length $v] > 0} {
						set v $ADMUSR($v)
					}
				}
				set DATA($r,$c,val)  $v
				set DATA($r,$c,same) 1
			}
		} else {
			set p [expr {$r-1}]
			for {set c 0} {$c < $n_cols} {incr c} {
				set n [lindex $p_cols $c]
				set s [db_get_col $res $p $n]
				set t [db_get_col $res $r $n]
				# substitute if this is an admin user id
				if {[lsearch -exact $admusr $n] >= 0} {
					if {$what == "CustLimits" && $t == "-1"} {
						set DATA($r,$c,val) "Customer"
						if {$s == $t} {
							set DATA($r,$c,same) 1
						} else {
							set DATA($r,$c,same) 0
						}
						continue
					} elseif {[string length $t] > 0} {
						set t $ADMUSR($t)
					}
				}
				set DATA($r,$c,val) $t
				if {$s == $t} {
					set DATA($r,$c,same) 1
				} else {
					set DATA($r,$c,same) 0
				}
			}
		}
	}

	db_close $res

	tpBindVar ColName DATA name col_idx
	tpBindVar Data    DATA val  row_idx col_idx


	#
	# Bind hidden form elements for the "back" action
	#
	for {set h 0} {$h < [llength $AUDIT_INFO($what,hidden)]} {incr h} {
		set n [lindex $AUDIT_INFO($what,hidden) $h]
		set HIDDEN($h,name)  $n
		set HIDDEN($h,value) [reqGetArg $n]
	}

	tpSetVar NumHidden $h

	tpBindVar HiddenName  HIDDEN name  hidden_idx
	tpBindVar HiddenValue HIDDEN value hidden_idx

	if {$what == "Xlation"} {
		tpSetVar HideBack 0
	}
	tpBindString BackAction $AUDIT_INFO($what,action)

	asPlayFile -nocache audit_info.html

	catch {unset DATA}
	catch {unset HIDDEN}
}



proc do_audit_back args {

	back_action_refresh
	set p [reqGetArg BackAction]

	$p
}

}
