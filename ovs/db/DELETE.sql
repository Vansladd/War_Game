!echo Deleting from tAdminOp where type = 'VRF'
delete from tAdminOp where type = 'VRF';

!echo Deleting from tAdminOpType where type = 'VRF'
delete from tAdminOpType where type = 'VRF';

!echo Deleting from tVrfURUType
delete from tVrfURUType;

!echo Deleting from tVrfGenType
delete from tVrfGenType;

!echo Deleting from tVrfChkType
delete from tVrfChkType;

!echo Deleting from tVrfCustReason
delete from tVrfCustReason;
