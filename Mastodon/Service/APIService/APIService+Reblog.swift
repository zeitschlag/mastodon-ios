//
//  APIService+Reblog.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-9.
//

import Foundation
import Combine
import MastodonSDK
import CoreData
import CoreDataStack
import CommonOSLog

extension APIService {
    
    // make local state change only
    func boost(
        tootObjectID: NSManagedObjectID,
        mastodonUserObjectID: NSManagedObjectID,
        boostKind: Mastodon.API.Status.Reblog.BoostKind
    ) -> AnyPublisher<Toot.ID, Error> {
        var _targetTootID: Toot.ID?
        let managedObjectContext = backgroundManagedObjectContext
        return managedObjectContext.performChanges {
            let toot = managedObjectContext.object(with: tootObjectID) as! Toot
            let mastodonUser = managedObjectContext.object(with: mastodonUserObjectID) as! MastodonUser
            let targetToot = toot.reblog ?? toot
            let targetTootID = targetToot.id
            _targetTootID = targetTootID

            targetToot.update(reblogged: boostKind == .boost, mastodonUser: mastodonUser)

        }
        .tryMap { result in
            switch result {
            case .success:
                guard let targetTootID = _targetTootID else {
                    throw APIError.implicit(.badRequest)
                }
                return targetTootID

            case .failure(let error):
                assertionFailure(error.localizedDescription)
                throw error
            }
        }
        .eraseToAnyPublisher()
    }

    // send boost request to remote
    func boost(
        statusID: Mastodon.Entity.Status.ID,
        boostKind: Mastodon.API.Status.Reblog.BoostKind,
        mastodonAuthenticationBox: AuthenticationService.MastodonAuthenticationBox
    ) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Status>, Error> {
        let domain = mastodonAuthenticationBox.domain
        let authorization = mastodonAuthenticationBox.userAuthorization
        let requestMastodonUserID = mastodonAuthenticationBox.userID
        return Mastodon.API.Status.Reblog.boost(
            session: session,
            domain: domain,
            statusID: statusID,
            boostKind: boostKind,
            authorization: authorization
        )
        .map { response -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Status>, Error> in
            let log = OSLog.api
            let entity = response.value
            let managedObjectContext = self.backgroundManagedObjectContext

            return managedObjectContext.performChanges {
                let _requestMastodonUser: MastodonUser? = {
                    let request = MastodonUser.sortedFetchRequest
                    request.predicate = MastodonUser.predicate(domain: mastodonAuthenticationBox.domain, id: requestMastodonUserID)
                    request.fetchLimit = 1
                    request.returnsObjectsAsFaults = false
                    do {
                        return try managedObjectContext.fetch(request).first
                    } catch {
                        assertionFailure(error.localizedDescription)
                        return nil
                    }
                }()
                let _oldToot: Toot? = {
                    let request = Toot.sortedFetchRequest
                    request.predicate = Toot.predicate(domain: domain, id: statusID)
                    request.returnsObjectsAsFaults = false
                    request.relationshipKeyPathsForPrefetching = [#keyPath(Toot.reblog)]
                    do {
                        return try managedObjectContext.fetch(request).first
                    } catch {
                        assertionFailure(error.localizedDescription)
                        return nil
                    }
                }()

                guard let requestMastodonUser = _requestMastodonUser,
                      let oldToot = _oldToot else {
                    assertionFailure()
                    return
                }
                APIService.CoreData.merge(toot: oldToot, entity: entity.reblog ?? entity, requestMastodonUser: requestMastodonUser, domain: mastodonAuthenticationBox.domain, networkDate: response.networkDate)
                os_log(.info, log: log, "%{public}s[%{public}ld], %{public}s: did update toot %{public}s reblog status to: %{public}s. now %ld boosts", ((#file as NSString).lastPathComponent), #line, #function, entity.id, entity.reblogged.flatMap { $0 ? "boost" : "unboost" } ?? "<nil>", entity.reblogsCount )
            }
            .setFailureType(to: Error.self)
            .tryMap { result -> Mastodon.Response.Content<Mastodon.Entity.Status> in
                switch result {
                case .success:
                    return response
                case .failure(let error):
                    throw error
                }
            }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveCompletion: { completion in
            switch completion {
            case .failure(let error):
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: error:", ((#file as NSString).lastPathComponent), #line, #function)
                debugPrint(error)
            case .finished:
                break
            }
        })
        .eraseToAnyPublisher()
    }

}

extension APIService {
//    func likeList(
//        limit: Int = onceRequestTootMaxCount,
//        userID: String,
//        maxID: String? = nil,
//        mastodonAuthenticationBox: AuthenticationService.MastodonAuthenticationBox
//    ) -> AnyPublisher<Mastodon.Response.Content<[Mastodon.Entity.Status]>, Error> {
//
//        let requestMastodonUserID = mastodonAuthenticationBox.userID
//        let query = Mastodon.API.Favorites.ListQuery(limit: limit, minID: nil, maxID: maxID)
//        return Mastodon.API.Favorites.favoritedStatus(domain: mastodonAuthenticationBox.domain, session: session, authorization: mastodonAuthenticationBox.userAuthorization, query: query)
//            .map { response -> AnyPublisher<Mastodon.Response.Content<[Mastodon.Entity.Status]>, Error> in
//                let log = OSLog.api
//
//                return APIService.Persist.persistTimeline(
//                    managedObjectContext: self.backgroundManagedObjectContext,
//                    domain: mastodonAuthenticationBox.domain,
//                    query: query,
//                    response: response,
//                    persistType: .likeList,
//                    requestMastodonUserID: requestMastodonUserID,
//                    log: log
//                )
//                .setFailureType(to: Error.self)
//                .tryMap { result -> Mastodon.Response.Content<[Mastodon.Entity.Status]> in
//                    switch result {
//                    case .success:
//                        return response
//                    case .failure(let error):
//                        throw error
//                    }
//                }
//                .eraseToAnyPublisher()
//            }
//            .switchToLatest()
//            .eraseToAnyPublisher()
//    }
}
