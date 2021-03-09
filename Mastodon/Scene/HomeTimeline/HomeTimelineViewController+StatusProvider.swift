//
//  HomeTimelineViewController+StatusProvider.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/2/5.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack

// MARK: - StatusProvider
extension HomeTimelineViewController: StatusProvider {

    func toot() -> Future<Toot?, Never> {
        return Future { promise in promise(.success(nil)) }
    }
    
    func toot(for cell: UITableViewCell, indexPath: IndexPath?) -> Future<Toot?, Never> {
        return Future { promise in
            guard let diffableDataSource = self.viewModel.diffableDataSource else {
                assertionFailure()
                promise(.success(nil))
                return
            }
            guard let indexPath = indexPath ?? self.tableView.indexPath(for: cell),
                  let item = diffableDataSource.itemIdentifier(for: indexPath) else {
                promise(.success(nil))
                return
            }
            
            switch item {
            case .homeTimelineIndex(let objectID, _):
                let managedObjectContext = self.viewModel.fetchedResultsController.managedObjectContext
                managedObjectContext.perform {
                    let timelineIndex = managedObjectContext.object(with: objectID) as? HomeTimelineIndex
                    promise(.success(timelineIndex?.toot))
                }
            default:
                promise(.success(nil))
            }
        }
    }
    
    func toot(for cell: UICollectionViewCell) -> Future<Toot?, Never> {
        return Future { promise in promise(.success(nil)) }
    }
    
    var managedObjectContext: NSManagedObjectContext {
        return viewModel.fetchedResultsController.managedObjectContext
    }
    
    var tableViewDiffableDataSource: UITableViewDiffableDataSource<StatusSection, Item>? {
        return viewModel.diffableDataSource
    }
    
    func item(for cell: UITableViewCell?, indexPath: IndexPath?) -> Item? {
        guard let diffableDataSource = self.viewModel.diffableDataSource else {
            assertionFailure()
            return nil
        }
        
        guard let indexPath = indexPath ?? cell.flatMap({ self.tableView.indexPath(for: $0) }),
              let item = diffableDataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        return item
    }
    
}