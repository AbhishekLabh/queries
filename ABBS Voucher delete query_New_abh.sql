DECLARE @AUTOV_ID INT=331542
    DECLARE @TRAN_DATE DATE='2019-07-16'
    DECLARE @MSG VARCHAR(MAX)=''
    DECLARE @L_ID INT=0
    DECLARE @CREATED_BY INT=7
    DECLARE @BRANC_ID INT=48
    
    DECLARE CURVOUCHER INSENSITIVE CURSOR FOR
    --------------------------------PLEASE ENTER AUTO_VID IN BETWEEN BRACKET BELOW REMOVING @AUTOV_ID--------------------------------------------------
                   SELECT AUTO_VID,TRAN_DATE,BRANCH_ID FROM TBL_VOUCHER WHERE Auto_vID=@AUTOV_ID AND TRAN_DATE=@TRAN_DATE
    ---------------------------------------------------------------------------------------------------------------------------------------------------
                   OPEN CURVOUCHER
                   Fetch Next from CURVOUCHER Into @AUTOV_ID,@TRAN_DATE,@BRANC_ID
                   While @@FETCH_STATUS = 0
                         Begin       
                        DECLARE @SYS_DATE DATETIME=(SELECT TRANSACTION_DATE FROM TBL_SYSTEM_DATE_SETTINGS WHERE BRANCHID=@BRANC_ID )
                        DECLARE @ALLOW BIT=1
                            --SET @AUTOV_ID=(SELECT Auto_vID FROM tbl_Voucher WHERE User_Voucher_No=@NARRATION)
                            IF EXISTS(SELECT Mem_Id FROM Acc_Mem WHERE Status=0 AND
                                    AccountNo IN(SELECT AccountNo FROM Account WHERE L_ID IN(SELECT L_ID FROM TBL_CHILD_VOUCHER WHERE Auto_vID=@AUTOV_ID)))
                            BEGIN
                                SET @ALLOW=0
                                SET @MSG='Account already closed!!'
                            END
                                
                                select @MSG,@ALLOW
                                -----start region ,you can disable by commenting these line to delete saving voucher in descending order
                                --SET @L_ID=(SELECT L_ID FROM TBL_CHILD_VOUCHER WHERE Auto_vID=@AUTOV_ID AND L_ID IN(SELECT L_ID FROM Account))
                                --IF(ISNULL(@L_ID,0)>0)
                                --BEGIN
                                --    IF EXISTS(SELECT Auto_vID FROM TBL_CHILD_VOUCHER WHERE L_ID IN(@L_ID)AND Auto_vID>@AUTOV_ID)
                                --    BEGIN
                                --        SET @ALLOW=0
                                --        SET @MSG='Please delete saving voucher in descending order!!'
                                --    END
                                --END
                                ------------end region
    
                            SET @L_ID=(SELECT L_ID FROM TBL_CHILD_VOUCHER WHERE Auto_vID=@AUTOV_ID AND L_ID IN(SELECT L_ID FROM LOAN))
                            IF(ISNULL(@L_ID,0)>0)
                                BEGIN
                                    DECLARE @HEADER1 VARCHAR(400)=ISNULL((SELECT LOANNO FROM LOAN WHERE L_id=@L_ID),'')
                                END
                            ELSE
                                BEGIN
                                    SET @HEADER1=''
                                END
    
                            IF EXISTS(SELECT LoanId FROM LoanPayment WHERE LoanId=@HEADER1)AND @HEADER1!=''
                            BEGIN
                                IF (SELECT COUNT(LoanId) FROM LoanPayment WHERE LoanId=@HEADER1 AND PaymentDate=@TRAN_DATE)>1
                                BEGIN
                                    IF (SELECT TOP 1 VID FROM LoanPayment WHERE LoanId=@HEADER1 AND PaymentDate=@TRAN_DATE ORDER BY VID DESC)=@AUTOV_ID
                                    SET @ALLOW=1
                                    ELSE
                                    BEGIN
                                        SET @ALLOW=0
                                        SET @MSG='Please delete loan voucher in decending order!!'
                                    END
                                END
                            END
                            IF EXISTS(SELECT Tran_ID FROM TBL_UTIL_TRANSACTION WHERE (Tran_ID=@AUTOV_ID OR Code2=@AUTOV_ID) AND Util_Date=@TRAN_DATE AND Result=1)
                                BEGIN
                                    SET @ALLOW=0
                                    SET @MSG='Cant Allowed to delete! zPay successeded voucher'
                                END
                                select @MSG,@ALLOW
                            IF @ALLOW=1
                            BEGIN
                            --------------------DELETE VOUCHER HISTORY--------------------------------------
                                INSERT INTO TBL_DELETED_VOUCHER
                                ([Auto_vID]
                                  ,[Voucher_ID]
                                  ,[PreparedBy]
                                  ,[ApprovedBy]
                                  ,[CheckedBy]
                                  ,[Narration]
                                  ,[Total_Amount]
                                  ,[vtype]
                                  ,[Tid]
                                  ,[Tran_Date]
                                  ,[V_RefNo]
                                  ,[Branch_ID]
                                  ,[Company_ID]
                                  ,[Dr_Amount]
                                  ,[Cr_Amount]
                                  ,[User_Voucher_No]
                                  ,[CHILD_Narration]
                                  ,[C_V_ID]
                                  ,[Achead_ID]
                                  ,[L_ID]
                                  ,[Ledger_Code]
                                  ,[Acc_Type_ID]
                                  ,[USER_LEDGER_CODE]
                                  ,[USER_P_LEDGER_CODE]
                                  ,[DELETED_BY]
                                  ,[DELETED_DATE])
      
                                  SELECT TV.[Auto_vID]
                                  ,[Voucher_ID]
                                  ,[PreparedBy]
                                  ,[ApprovedBy]
                                  ,[CheckedBy]
                                  ,TV.[Narration]
                                  ,[Total_Amount]
                                  ,[vtype]
                                  ,[Tid]
                                  ,[Tran_Date]
                                  ,[V_RefNo]
                                  ,[Branch_ID]
                                  ,[Company_ID]
                                  ,[Dr_Amount]
                                  ,[Cr_Amount]
                                  ,[User_Voucher_No]
                                  ,CV.[Narration]
                                  ,[C_V_ID]
                                  ,[Achead_ID]
                                  ,[L_ID]
                                  ,CV.[Ledger_Code]
                                  ,[Acc_Type_ID]
                                  ,[USER_LEDGER_CODE]
                                  ,[USER_P_LEDGER_CODE],@CREATED_BY,@SYS_DATE FROM tbl_Voucher TV
                                  INNER JOIN TBL_CHILD_VOUCHER CV ON TV.Auto_vID=CV.Auto_vID  where TV.Auto_vID =@AUTOV_ID
        
                                ------------------SAVING DEPOSIT/WITHDRAW------------------------------------
                                update Account set DTotal=DTotal-Cr_Amount from Account a
                                inner join TBL_CHILD_VOUCHER cv on a.L_ID=cv.L_ID where Auto_vID =@AUTOV_ID  
                                and Dr_Amount=0 and Cr_Amount<>0

                                update Account set WTotal=WTotal-dr_Amount from Account a
                                inner join TBL_CHILD_VOUCHER cv on a.L_ID=cv.L_ID where Auto_vID =@AUTOV_ID
                                and Cr_Amount=0 and Dr_Amount<>0
        
                                update BankDesc set TDAmt=TDAmt-Dr_Amount from BankDesc a
                                inner join TBL_CHILD_VOUCHER cv on a.L_ID=cv.L_ID where Auto_vID =@AUTOV_ID  
                                and Cr_Amount=0 and Dr_Amount<>0

                                update BankDesc set TWAmt=TWAmt-Cr_Amount from BankDesc a
                                inner join TBL_CHILD_VOUCHER cv on a.L_ID=cv.L_ID where Auto_vID =@AUTOV_ID
                                and Dr_Amount=0 and Cr_Amount<>0
                                DELETE FROM LAAmount WHERE VoucherNo=@AUTOV_ID
        
                                --DELETE FROM IncomeExpAmount WHERE VoucherNo=@AUTOV_ID
        
                                DELETE FROM Deposit WHERE V_id=@AUTOV_ID
                                DELETE FROM MonthlySaving WHERE vid=@AUTOV_ID
                                DELETE FROM Withdraw WHERE V_id=@AUTOV_ID
                                DELETE FROM ReceiptPayment WHERE VoucherNo=@AUTOV_ID
                                DELETE FROM Bank WHERE VoucherNo=@AUTOV_ID
        
                                --------------SHARE PURCHASE-------------------------
                                DELETE FROM SharePurchase WHERE vid=@AUTOV_ID
                                DELETE FROM ShareReturn WHERE vid=@AUTOV_ID
                                update Membership SET ShareNo=ISNULL((select sum(ShareNo) from SharePurchase Sp1 where Sp1.MemberShip_ID=Ms1.MemberShip_ID),0)
                                -ISNULL((select sum(Sr1.ShareNo) from ShareReturn Sr1 where Sr1.Membership_ID=Ms1.MemberShip_id),0) from Membership ms1
        
                                --------------LOAN------------------------------------
                                DECLARE @PAYMENTMODE INT
        
                                IF NOT EXISTS(SELECT * FROM LoanPayment WHERE LoanId=@HEADER1)AND @HEADER1!='' -------LOAN ISSUE DELETE------
                                BEGIN     
                                    DELETE FROM TBL_LOAN_AGING_DAILY WHERE LOAN_NO=@HEADER1
                                    DELETE FROM TBL_DAILY_LOAN_INTEREST WHERE LOAN_NO=@HEADER1
                                    DELETE FROM LOAN WHERE L_ID=@L_ID
                                    DELETE FROM TBL_LEDGER WHERE L_ID=@L_ID    
                                    DELETE FROM LoanPayAmt WHERE LoanNo=@HEADER1
                                    DELETE FROM tbl_NextPaymentDate WHERE LoanNo=@HEADER1
                                    DELETE FROM EMI WHERE LOANNO=@HEADER1
                                    --DELETE FROM IncomeExpAmount WHERE VoucherNo=@AUTOV_ID
                                    --DELETE FROM LAAmount WHERE VoucherNo=@AUTOV_ID
                                    DELETE FROM SharePurchase WHERE vid=@AUTOV_ID
                                    --DELETE FROM ReceiptPayment WHERE VoucherNo=@AUTOV_ID
                                    DELETE FROM Colateral WHERE LoanNo=@HEADER1
                                    DELETE FROM Guarentee WHERE LoanNo=@HEADER1
                                    DELETE FROM DiminishingPayType WHERE LoanId=@HEADER1
                                END
                                ELSE -------LOAN PAYMENT DELETE------
                                BEGIN
                                    DELETE FROM LoanPayment WHERE vid=@AUTOV_ID
                                    DELETE FROM LoanReceipt WHERE vid=@AUTOV_ID
                                    DELETE FROM loanpayamt WHERE AUTO_VID=@AUTOV_ID
                                    --DELETE FROM ReceiptPayment WHERE VoucherNo=@AUTOV_ID
                                    --DELETE FROM IncomeExpAmount WHERE VoucherNo=@AUTOV_ID        
                                    DELETE FROM LoanDue WHERE v_id=@AUTOV_ID                
                                    DELETE FROM TBL_LOAN_PAYMENT_DETAIL WHERE AUTO_VID=@AUTOV_ID
                                    --UPDATE LOAN SET L_Total=(select sum(pay_amount) from loanpayamt where loanno=@HEADER1)-isnull(isnull((SELECT sum(L_PAMT) FROM LoanReceipt WHERE L_ID=@HEADER1),(SELECT sum(Principle) FROM loanpayment WHERE loanid=@HEADER1)),0) WHERE L_id=@L_ID
            
                                        IF(ISNULL(@L_ID,0)>0)
                                        BEGIN
                                        update loan set L_Total=isnull((select isnull(SUM(ISNULL(dr_amount,0)),0)-isnull(sum(isnull(Cr_Amount,0)),0)from tbl_child_voucher where L_ID=l.l_id),0) from loan l where LoanNo=@HEADER1             
                                        END
                                        
                                        SET @PAYMENTMODE=(SELECT case when InstallmentType=1 then 1 when InstallmentType=2 then 4 when InstallmentType=3 then 6 else 12 end FROM Loan WHERE LoanNo=@HEADER1)
                                        UPDATE tbl_NextPaymentDate SET NextDate=DATEADD("MONTH",-@PAYMENTMODE,NextDate) WHERE LoanNo=@HEADER1
                                    
            
                                END
                                DELETE FROM TBL_CHILD_VOUCHER WHERE Auto_vID=@AUTOV_ID
                                delete from TBL_BILL_PRINT where AUTO_VID=@AUTOV_ID
                                DELETE FROM tbl_Voucher WHERE Auto_vID=@AUTOV_ID
        
                                IF(ISNULL(@L_ID,0)>0)
                                BEGIN
                                    update loan set L_Total=isnull((select isnull(SUM(ISNULL(dr_amount,0)),0)-isnull(sum(isnull(Cr_Amount,0)),0)from tbl_child_voucher
                                    where L_ID=l.l_id),0) from loan l where LoanNo=@HEADER1             
                                END
        
                                SET @MSG='Deleted successfully!!'
                            END
                            
                   Fetch Next from CURVOUCHER Into @AUTOV_ID,@TRAN_DATE,@BRANC_ID
                   END
                   DEALLOCATE CURVOUCHER