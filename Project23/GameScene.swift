//
//  GameScene.swift
//  Project23
//
//  Created by Pablo Rodrigues on 20/01/2023.
//
import AVFoundation
import SpriteKit

enum Forcebomb {
    case never, always, random
}

enum sequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, thee, four, chain, fastchain
}

class GameScene: SKScene {
    
    
    var gameScore: SKLabelNode!
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var score = 0 {
        didSet {
            gameScore.text = "Score \(score)"
        }
    }
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    
    var activeSlicesPoints = [CGPoint]()
    
    var isSwooshSound = false
    var activeEnemys = [SKSpriteNode]()
    var bombSoundEffect: AVAudioPlayer?
    
    var popUpTime = 0.9
    var sequence = [sequenceType]()
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueued = true
    var isGameEndded = false
    

    
    override func didMove(to view: SKView) {
        
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.zPosition = -1
        background.blendMode = .replace
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlice()
        
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .thee, .two, .chain]
        
        for _ in 0...1000 {
            if let nextSequence = sequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [weak self] in self?.tossEnemy()
        }
        
    }
    
    func createScore(){
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.position = CGPoint(x: 8, y: 50)
        gameScore.fontSize = 48
        addChild(gameScore)
        
        score = 0
    }
    func createLives(){
        
        for i in 0..<3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 700)
            addChild(spriteNode)
            livesImages.append(spriteNode)
        }
    }
    
    func createSlice(){
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard isGameEndded == false else {return}
        
        guard let touch = touches.first else {return}
        let location = touch.location(in: self)
        
        activeSlicesPoints.append(location)
        redrawActiveSlice()
        
        if !isSwooshSound {
            createSwoosh()
        }
        
        let nodeAtPosition = nodes(at: location)
        
        for case let node as SKSpriteNode in nodeAtPosition {
            
            if node.name == "fasterEnemy" {
                score += 4
            }
            
            
            
            if node.name == "enemy" || node.name == "fasterEnemy"{
//                destroy penguin
                
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
                    emitter.position = node.position
                    addChild(emitter)
                }
                
                node.name = ""
                node.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                node.run(seq)
                
                score += 1
                
                if let index = activeEnemys.firstIndex(of: node) {
                    activeEnemys.remove(at: index)
                }
                
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
            } else if node.name == "bomb" {
                //                destroys bomb
                
                guard let bombContainer = node.parent as? SKSpriteNode else {continue}
                
              if  let emitter = SKEmitterNode(fileNamed: "sliceHitBomb"){
                emitter.position = bombContainer.position
                addChild(emitter)
              }
                
                node.name = ""
                bombContainer.physicsBody?.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, .removeFromParent()])
                bombContainer.run(seq)
                
                if let index = activeEnemys.firstIndex(of: bombContainer) {
                    activeEnemys.remove(at: index)
                }
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggedByBomb: true)
           }
        }
        
    }
    
    func endGame(triggedByBomb: Bool) {
        guard isGameEndded == false else {return}
        
        let gameOverLabel = SKSpriteNode(imageNamed: "gameOver")
        gameOverLabel.position = CGPoint(x: 512, y: 400)
        gameOverLabel.size = CGSize(width: 550, height: 80)
        
        
      
        
        isGameEndded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        addChild(gameOverLabel)
        
        bombSoundEffect?.stop()
        bombSoundEffect = nil
        
        
        if triggedByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
    }
    
    func createSwoosh(){
        
        let randomNumber = Int.random(in: 1...3)
        let swooshName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(swooshName, waitForCompletion: true)
        
        run(swooshSound) {[weak self] in
            self?.isSwooshSound = false
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        activeSlicesPoints.removeAll(keepingCapacity: true)
        
        let location = touch.location(in: self)
        activeSlicesPoints.append(location)
        
        redrawActiveSlice()
        
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        activeSliceFG.alpha = 1
        activeSliceBG.alpha = 1
    }
    
    func redrawActiveSlice() {
        if activeSlicesPoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
        }
        
        if activeSlicesPoints.count > 12 {
            activeSlicesPoints.removeFirst(activeSlicesPoints.count - 12)
        }
        
        let path = UIBezierPath()
        path.move(to: activeSlicesPoints[0])
        
        for i in 1 ..< activeSlicesPoints.count{
            path.addLine(to: activeSlicesPoints[i])
            
            activeSliceFG.path = path.cgPath
            activeSliceBG.path = path.cgPath
        }
    }
    
    func createEnemys(forceBomb: Forcebomb = .random) {
        let enemy: SKSpriteNode
        
        var enemyType = Int.random(in: 0...7)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                if let sound = try? AVAudioPlayer(contentsOf: path){
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
            }
            
            
        } else if enemyType == 7 {
            enemy = SKSpriteNode(imageNamed: "eagle")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            
            enemy.name = "fasterEnemy"
        }
         else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            
            enemy.name = "enemy"
        }
    
       
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        let randomAngularVelocity = CGFloat.random(in: -3...3)
        let randomXVelocity : Int
        
        if randomPosition.x < 256 {
            randomXVelocity = Int.random(in: 8...15)
        } else if randomPosition.x < 512 {
            randomXVelocity = Int.random(in: 3...5)
        } else if randomPosition.x < 768 {
            randomXVelocity = Int.random(in: 3...5)
        } else {
            randomXVelocity = -Int.random(in: 8...15)
        }
        
        let randomYVelocity = Int.random(in: 24...32)
        
        
//        let SFE = enemyType == 7 ? randomXVelocity : 2
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        

        
        addChild(enemy)
        activeEnemys.append(enemy)
    }
    
    func subtractLife(){
        lives -= 1
       
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggedByBomb: false)
        }
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration: 0.1))
      
        
        
        
        
    }
    
    override func update(_ currentTime: TimeInterval) {
        if activeEnemys.count > 0 {
            for (index, node) in activeEnemys.enumerated().reversed() {
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    if node.name == "enemy" {
                        node.name = ""
                        subtractLife()
                        node.removeFromParent()
                        activeEnemys.remove(at: index)
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        activeEnemys.remove(at: index)
                    }
                }
            }
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popUpTime) {
                    [weak self] in self?.tossEnemy()
                }
                nextSequenceQueued = true
            }
        }
        
        var bombCount = 0
        
        for node in activeEnemys {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        if bombCount == 0 {
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
    }
    
    func tossEnemy(){
        
        guard isGameEndded == false else {return}
        
        popUpTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .oneNoBomb :
            createEnemys(forceBomb: .never)
            
        case .one :
            createEnemys()
            
            
        case .twoWithOneBomb :
            createEnemys(forceBomb: .never)
            createEnemys(forceBomb: .always)
            
        case.two :
            createEnemys()
            createEnemys()
            
        case.thee :
            createEnemys()
            createEnemys()
            createEnemys()
        case.four :
            createEnemys()
            createEnemys()
            createEnemys()
            createEnemys()
            
        case.chain :
            createEnemys()
          
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 5)) {[weak self] in self?.createEnemys()}
        case.fastchain :
            createEnemys()
           
            
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) {[weak self] in self?.createEnemys()}
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 5)) {[weak self] in self?.createEnemys()}
            
            
        }
        
        sequencePosition += 1
        nextSequenceQueued = false
    }
    
  
}
