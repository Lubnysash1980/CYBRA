// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRADualLicenseRoyalty15.sol";

contract CYBRADualLicenseRoyalty15SecurityTest is Test {
    CYBRADualLicenseRoyalty15 license;

    address authority = address(0xA001);
    address verifier1 = address(0xA002);
    address verifier2 = address(0xA003);
    address holder = address(0xA004);

    bytes32 licenseId = keccak256("CYBRA-LICENSE-SECURITY");
    bytes32 commitHash = keccak256("COMMIT");
    bytes32 repositoryHash = keccak256("REPOSITORY");
    bytes32 evidenceHash = keccak256("EVIDENCE");

    function setUp() public {
        vm.prank(authority);
        license = new CYBRADualLicenseRoyalty15(
            verifier1,
            verifier2
        );

        vm.prank(authority);
        license.registerLicense(
            licenseId,
            commitHash,
            repositoryHash,
            holder
        );
    }

    function _approveBoth() internal {
        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        vm.prank(verifier2);
        license.approveViolation(
            licenseId,
            evidenceHash
        );
    }

    function _set100() internal {
        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            100
        );
    }

    function _setProfit() internal {
        vm.prank(authority);
        license.confirmProfit(
            licenseId,
            10000
        );
    }

    // 1. Без verifier-підтверджень TRUE_100 неможливий.
    function test_SECURITY_NoVerifierCannotBecomeTRUE100() public {
        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        vm.prank(authority);
        vm.expectRevert("VERIFIER1_REQUIRED");
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 2. Один verifier не може створити TRUE_100.
    function test_SECURITY_OneVerifierCannotBecomeTRUE100() public {
        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmProfit(
            licenseId,
            10000
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 3. 99/100 не може стати TRUE_100.
    function test_SECURITY_99PercentCannotBecomeTRUE100() public {
        _approveBoth();
        _setProfit();

        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            99
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 4. 0/100 не може стати TRUE_100.
    function test_SECURITY_ZeroPercentCannotBecomeTRUE100() public {
        _approveBoth();
        _setProfit();

        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            0
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 5. Без прибутку TRUE_100 неможливий.
    function test_SECURITY_NoProfitCannotBecomeTRUE100() public {
        _approveBoth();
        _set100();

        vm.prank(authority);
        vm.expectRevert();
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 6. Різні evidence hash між verifier-ами блокують підтвердження.
    function test_SECURITY_MismatchedEvidenceBlocksTRUE100() public {
        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        vm.prank(verifier2);
        vm.expectRevert();
        license.approveViolation(
            licenseId,
            keccak256("DIFFERENT-EVIDENCE")
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmProfit(
            licenseId,
            10000
        );

        assertFalse(license.isTRUE100(licenseId));
    }

    // 7. Неавторизований address не може змінити confirmation.
    function test_SECURITY_UnauthorizedCannotSet100() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        assertFalse(license.isTRUE100(licenseId));
    }

    // 8. Неавторизований address не може підтвердити profit.
    function test_SECURITY_UnauthorizedCannotConfirmProfit() public {
        _approveBoth();

        vm.prank(address(0xBEEF));
        vm.expectRevert();
        license.confirmProfit(
            licenseId,
            10000
        );

        assertFalse(license.isTRUE100(licenseId));
    }

    // 9. Навіть повні 100/100 без dual approval залишають TRUE_100 = false.
    function test_SECURITY_100PercentWithoutDualApprovalBlocked() public {
        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        vm.prank(authority);
        vm.expectRevert();
        license.confirmTRUE100(licenseId);

        assertFalse(license.isTRUE100(licenseId));
    }

    // 10. Повний коректний шлях повинен пройти.
    function test_SECURITY_ValidPathReachesTRUE100() public {
        _approveBoth();
        _setProfit();
        _set100();

        vm.prank(authority);
        license.confirmTRUE100(licenseId);

        assertTrue(license.isTRUE100(licenseId));

        (
            uint256 profit,
            uint256 royalty
        ) = license.getRoyaltyState(licenseId);

        assertEq(profit, 10000);
        assertEq(royalty, 1500);
    }
}
