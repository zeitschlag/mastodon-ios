// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonSDK
import MastodonCore

struct NotificationRequestsViewModel {
    var requests: [Mastodon.Entity.NotificationRequest]
    let authContext: AuthContext
}

enum NotificationRequestsSection: Hashable {
    case main
}

enum NotificationRequestItem: Hashable {
    case item(Mastodon.Entity.NotificationRequest)
}

class NotificationRequestsTableViewController: UIViewController, NeedsDependency {

    var context: AppContext!
    var coordinator: SceneCoordinator!


    let tableView: UITableView
    var viewModel: NotificationRequestsViewModel
    var dataSource: UITableViewDiffableDataSource<NotificationRequestsSection, NotificationRequestItem>?

    init(viewModel: NotificationRequestsViewModel, appContext: AppContext, coordinator: SceneCoordinator) {

        self.viewModel = viewModel
        self.context = appContext
        self.coordinator = coordinator

        tableView = UITableView(frame: .zero)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .secondarySystemBackground
        tableView.register(NotificationRequestTableViewCell.self, forCellReuseIdentifier: NotificationRequestTableViewCell.reuseIdentifier)

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        tableView.pinToParent()

        let dataSource = UITableViewDiffableDataSource<NotificationRequestsSection, NotificationRequestItem>(tableView: tableView) { tableView, indexPath, itemIdentifier in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: NotificationRequestTableViewCell.reuseIdentifier, for: indexPath) as? NotificationRequestTableViewCell else {
                fatalError("No NotificationRequestTableViewCell")
            }

            let request = viewModel.requests[indexPath.row]
            cell.configure(with: request)
            cell.delegate = self

            return cell
        }

        tableView.dataSource = dataSource
        tableView.delegate = self
        self.dataSource = dataSource

        //TODO: Localization
        title = "Filtered Notifications"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        var snapshot = NSDiffableDataSourceSnapshot<NotificationRequestsSection, NotificationRequestItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.requests.compactMap { NotificationRequestItem.item($0) } )

        dataSource?.apply(snapshot)
    }
}

// MARK: - UITableViewDelegate
extension NotificationRequestsTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let request = viewModel.requests[indexPath.row]

        Task {
            await DataSourceFacade.coordinateToNotificationRequest(request: request, provider: self)
        }
    }
}

// MARK: - AuthContextProvider
extension NotificationRequestsTableViewController: AuthContextProvider {
    var authContext: AuthContext { viewModel.authContext }
}

extension NotificationRequestsTableViewController: NotificationRequestTableViewCellDelegate {
    func acceptNotificationRequest(_ cell: NotificationRequestTableViewCell, notificationRequest: MastodonSDK.Mastodon.Entity.NotificationRequest) {
        print("accept \(notificationRequest.id)")
        cell.acceptNotificationRequestActivityIndicatorView.isHidden = false
        cell.acceptNotificationRequestActivityIndicatorView.startAnimating()

        cell.acceptNotificationRequestButton.tintColor = .clear
        cell.acceptNotificationRequestButton.setTitleColor(.clear, for: .normal)


        //TODO: Send request, update cell, reload notification requests AND general notifications
    }
    
    func rejectNotificationRequest(_ cell: NotificationRequestTableViewCell, notificationRequest: MastodonSDK.Mastodon.Entity.NotificationRequest) {
        print("reject \(notificationRequest.id)")

        cell.rejectNotificationRequestActivityIndicatorView.isHidden = false
        cell.rejectNotificationRequestActivityIndicatorView.startAnimating()
        cell.rejectNotificationRequestButton.tintColor = .clear
        cell.rejectNotificationRequestButton.setTitleColor(.clear, for: .normal)

    }
}
