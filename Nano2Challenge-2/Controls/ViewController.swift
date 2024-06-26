//
//  ViewController.swift
//  Nano2Challenge-2
//
//  Created by Bryan Vernanda on 15/05/24.
//

import UIKit
import SceneKit
import ARKit
import GameplayKit
import Combine
import SwiftUI

enum CollisionTypes: Int {
    case zombie = 1
    case castle = 2
    case arrow = 4
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate, ObservableObject {

    @IBOutlet var sceneView: ARSCNView!
    
    private var cancellable: Set<AnyCancellable> = []
    private var cancellable1: Set<AnyCancellable> = []
    private var cancellable2: Set<AnyCancellable> = []
    private var spawnTimer: DispatchSourceTimer?
    private var currentZPosition: Float = -5
    private let randomSource = GKRandomSource()
    private var limitZombies = 0
    private var zombieNumSpawn: Int = 10
    private var timeSpawn: CGFloat = 2.0
    private var timeWalking: CGFloat = 10.0
    @Binding var spawningZombiePage: Int
    let castle = Castle()
    
    @Published var completeKillingZombies: Bool = false
    
    init(spawningZombiePage: Binding<Int>) {
        self._spawningZombiePage = spawningZombiePage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self._spawningZombiePage = Binding.constant(1)
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ARManager.shared.setupARView(for: self.view)
        
        sceneView = ARManager.shared.sceneView
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
//        sceneView.showsStatistics = true
        
        // Show world anchor
//        sceneView.debugOptions = .showWorldOrigin
        
        sceneView.scene.physicsWorld.contactDelegate = self
        
        setupSendingCompleteKillingZombies()
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.castle.rawValue) {
            
            contact.nodeA.physicsBody?.categoryBitMask = 0 // this is not needed, but should be used to handle bug (collision multiple times)
            contact.nodeA.removeFromParentNode()
            (contact.nodeB as? Castle)?.takeDamage(spawningZombiePage: spawningZombiePage)
            
        } else if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.castle.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) {

            contact.nodeB.physicsBody?.categoryBitMask = 0 // this is not needed, but should be used to handle bug (collision multiple times)
            contact.nodeB.removeFromParentNode()
            (contact.nodeA as? Castle)?.takeDamage(spawningZombiePage: spawningZombiePage)
            
        }
        
        if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.arrow.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) {
            
            contact.nodeA.physicsBody?.categoryBitMask = 0 // this is not needed, but should be used to handle bug (collision multiple times)
            contact.nodeA.removeFromParentNode()
            (contact.nodeB as? Zombie)?.takeDamage()
            
        } else if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.arrow.rawValue) {
            
            contact.nodeB.physicsBody?.categoryBitMask = 0 // this is not needed, but should be used to handle bug (collision multiple times)
            contact.nodeB.removeFromParentNode()
            (contact.nodeA as? Zombie)?.takeDamage()
            
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Run the view's session
        sceneView.session.run(configuration)
        
        // Create an anchor at the world origin
        let anchor = ARAnchor(name: "zombieAnchor", transform: matrix_identity_float4x4)
        sceneView.session.add(anchor: anchor)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Invalidate the timer when the view disappears
        spawnTimer?.cancel()
        spawnTimer = nil
        
        castle.removeFromParentNode()
        removeZombieAndPlayerNodes()
        
        // Pause the view's session
        sceneView.session.pause()
        
        // Stop and reset the AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.removeFromSuperview()
        
        ARManager.shared.reset()
    }
    
    func removeZombieAndPlayerNodes() {
        // Loop through the child nodes of the root node
        for childNode in sceneView.scene.rootNode.childNodes {
            // Identify if the node is a zombie node
            if childNode.name == "zombie" {
                // Remove the zombie node from its parent node
                childNode.removeFromParentNode()
            }
        }
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor.name == "zombieAnchor" {
            // Add the castle to the scene
            addCastle(for: node)
            
            // Start spawning zombies at regular intervals in different pages
            if spawningZombiePage == 1 {
                startSpawningZombies(for: node, spawningCount: spawningZombiePage, zombieLimitNumber: zombieNumSpawn, timeSpawn: timeSpawn, timeWalking: timeWalking)
            } else if (spawningZombiePage == 2) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                    self.startSpawningZombies(for: node, spawningCount: self.spawningZombiePage, zombieLimitNumber: self.zombieNumSpawn, timeSpawn: self.timeSpawn, timeWalking: self.timeWalking)
                }
            }
            
            //spawning zombie button
            subscribeToActionStreamContinue(for: node, spawningCount: self.spawningZombiePage)
            
            // Attack button
            subscribeToActionStreamAtt(for: node)
        }
    }
    
    private func subscribeToActionStreamAtt(for node: SCNNode) {
        ARManager.shared
            .actionStream
            .sink { [weak self] action in //to make sure no app crashing or memory leaks, use weak self
                switch action {
                    case .attackButton:
                        self?.attackBowButton(for: node)
                }
            }//this is a subscribe, so customARView get inform whenever contentview sends an ARAction
            .store(in: &cancellable)
    }
    
    private func subscribeToActionStreamContinue(for node: SCNNode, spawningCount: Int) {
        ARManager.shared
            .actionStreamContinue
            .sink { [weak self] action in //to make sure no app crashing or memory leaks, use weak self
                switch action {
                    case .continueButton:
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self?.zombieNumSpawn += 20
                        self?.timeSpawn -= 0.5
                        self?.timeWalking -= 2.0
                        self?.completeKillingZombies = false
                        self?.castle.healBackCastle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                        self?.startSpawningZombies(for: node, spawningCount: spawningCount, zombieLimitNumber: self?.zombieNumSpawn ?? 20, timeSpawn: self?.timeSpawn ?? 20.0, timeWalking: self?.timeWalking ?? 20.0)
                    }
                }
            }//this is a subscribe, so customARView get inform whenever contentview sends an ARAction
            .store(in: &cancellable1)
    }
    
    private func setupSendingCompleteKillingZombies() {
        $completeKillingZombies
            .receive(on: DispatchQueue.main) // Ensure updates are received on the main thread
            .sink { [weak self] newValue in
                guard self != nil else { return }
            }
            .store(in: &cancellable2)
    }
    
    private func startSpawningZombies(for parentNode: SCNNode, spawningCount: Int, zombieLimitNumber: Int, timeSpawn: CGFloat, timeWalking: CGFloat) {
        // Create a dispatch timer to spawn zombies every 2 seconds
        spawnTimer?.cancel()  // Cancel any existing timer
        spawnTimer = DispatchSource.makeTimerSource()
        spawnTimer?.schedule(deadline: .now(), repeating: timeSpawn)
        spawnTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Generate a random x position between -5 and 5
                let randomXPosition = Float(self.randomSource.nextInt(upperBound: 11)) - 5.0
                
                // Spawn a zombie at the current position & limit the zombies
                if self.limitZombies < zombieLimitNumber {
                    self.spawnZombie(at: SCNVector3(x: randomXPosition, y: -0.5, z: self.currentZPosition), for: parentNode, timeWalking: timeWalking)
                    if spawningCount == 2 {
                        self.limitZombies += 1
                    }
                } else {
                    self.limitZombies = 0
                    self.completeKillingZombies = true
                    self.spawnTimer?.cancel()
                }
            }
        }
        spawnTimer?.resume()
    }
    
    private func spawnZombie(at position: SCNVector3, for parentNode: SCNNode, timeWalking: CGFloat) {
        let zombie = Zombie(at: position, timeWalking: timeWalking)
        parentNode.addChildNode(zombie)
    }
    
    private func addCastle(for parentNode: SCNNode) {
        parentNode.addChildNode(castle)
    }
    
    private func attackBowButton(for parentNode: SCNNode) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        // Get the camera transform
        let cameraTransform = currentFrame.camera.transform
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        // Set the arrow's orientation to match the camera's orientation
        let cameraOrientation = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        
        // send the camera position and orientation to the arrow to be launched
        let arrow = Arrow(at: cameraPosition, at: cameraOrientation)
        arrow.look(at: SCNVector3(cameraPosition.x + cameraOrientation.x, cameraPosition.y + cameraOrientation.y, cameraPosition.z + cameraOrientation.z))
        
        // Add the arrow to the scene
        parentNode.addChildNode(arrow)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // to remove scene every time deploy the arrow so reduce memory
            arrow.removeFromParentNode()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}






