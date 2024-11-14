// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import Combine
import Foundation
import MastodonSDK
import MastodonCore

extension HomeTimelineViewModel {

    func askForDonationIfPossible() async {
        let userAuthentication = authenticationBox
            .authentication
        guard let accountCreatedAt = userAuthentication.accountCreatedAt else {
            let updated = try? await context.apiService.accountVerifyCredentials(domain: userAuthentication.domain, authorization: authenticationBox.userAuthorization)
            guard let accountCreatedAt = updated?.createdAt else { return }
            AuthenticationServiceProvider.shared.updateAccountCreatedAt(accountCreatedAt, forAuthentication: userAuthentication)
            return
        }

        guard
            Mastodon.Entity.DonationCampaign.isEligibleForDonationsBanner(
                domain: userAuthentication.domain,
                accountCreationDate: accountCreatedAt)
        else { return }

        let seed = Mastodon.Entity.DonationCampaign.donationSeed(
            username: userAuthentication.username,
            domain: userAuthentication.domain)
        
        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let campaign = try await self.context.apiService
                    .getDonationCampaign(seed: seed, source: nil).value
                guard !Mastodon.Entity.DonationCampaign.hasPreviouslyDismissed(campaign.id) && !Mastodon.Entity.DonationCampaign.hasPreviouslyContributed(campaign.id) else { return }
                onPresentDonationCampaign.send(campaign)
            } catch {
                // no-op
            }
        }
    }
}