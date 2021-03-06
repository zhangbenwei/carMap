//
//  WBNetworkManager+Extension.swift
//  传智微博
//
//  Created by apple on 16/7/2.
//  Copyright © 2016年 itcast. All rights reserved.
//

import Foundation

// MARK: - 封装新浪微博的网络请求方法
extension WBNetworkManager {
    
    /// 加载微博数据字典数组
    ///
    /// - parameter since_id:   返回ID比since_id大的微博（即比since_id时间晚的微博），默认为0
    /// - parameter max_id:     返回ID小于或等于max_id的微博，默认为0
    /// - parameter completion: 完成回调[list: 微博字典数组/是否成功]
    func statusList(since_id: Int64 = 0, max_id: Int64 = 0, completion: (list: [[String: AnyObject]]?, isSuccess: Bool)->()) {
        
        let urlString = "https://api.weibo.com/2/statuses/home_timeline.json"
        
        // Swift 中 Int 可以转换成 AnyObject/ 但是 Int64 不行
        let params = ["since_id": "\(since_id)",
                      "max_id": "\(max_id > 0 ? max_id - 1 : 0)"]
        
        tokenRequest(URLString: urlString, parameters: params) { (json, isSuccess) in
            
            // 从 json 中获取 statuses 字典数组
            // 如果 as? 失败，result = nil
            // 提示：服务器返回的字典数组，就是按照时间的倒序排序的
            let result = json?["statuses"] as? [[String: AnyObject]]
            
            completion(list: result, isSuccess: isSuccess)
        }
    }
    
    /// 返回微博的未读数量 - 定时刷新，不需要提示是否失败！
    func unreadCount(completion: (count: Int)->()) {
        
        guard let uid = userAccount.uid else {
            return
        }
        
        let urlString = "https://rm.api.weibo.com/2/remind/unread_count.json"
        
        let params = ["uid": uid]
        
        tokenRequest(URLString: urlString, parameters: params) { (json, isSuccess) in
            
            let dict = json as? [String: AnyObject]
            let count = dict?["status"] as? Int
            
            completion(count: count ?? 0)
        }
    }
}

// MARK: - 发布微博
extension WBNetworkManager {
    
    /// 发布微博
    ///
    /// - parameter text:       要发布的文本
    /// - parameter image:      要上传的图像，为 nil 时，发布纯文本微博
    /// - parameter completion: 完成回调
    func postStatus(text: String, image: UIImage?, completion: (result: [String: AnyObject]?, isSuccess: Bool)->()) -> () {
        
        // 1. url
        let urlString: String
        
        // 根据是否有图像，选择不同的接口地址
        if image == nil {
            urlString = "https://api.weibo.com/2/statuses/update.json"
        } else {
            urlString = "https://upload.api.weibo.com/2/statuses/upload.json"
        }
        
        // 2. 参数字典
        let params = ["status": text]
        
        // 3. 如果图像不为空，需要设置 name 和 data 
        var name: String?
        var data: Data?
        
        if image != nil {
            name = "pic"
            data = UIImagePNGRepresentation(image!)
        }
        
        // 4. 发起网络请求
        tokenRequest(method: .POST, URLString: urlString, parameters: params, name: name, data: data) { (json, isSuccess) in
            completion(result: json as? [String: AnyObject], isSuccess: isSuccess)
        }
    }
}

// MARK: - 用户信息
extension WBNetworkManager {
    
    /// 加载当前用户信息 - 用户登录后立即执行
    func loadUserInfo(completion: (dict: [String: AnyObject])->()) {
        
        guard let uid = userAccount.uid else {
            return
        }
        
        let urlString = "https://api.weibo.com/2/users/show.json"
        
        let params = ["uid": uid]
        
        // 发起网络请求
        tokenRequest(URLString: urlString, parameters: params) { (json, isSuccess) in
            // 完成回调
            completion(dict: (json as? [String: AnyObject]) ?? [:])
        }
    }
}

// MARK: - OAuth相关方法
extension WBNetworkManager {
    
    /// 提问：网络请求异步到底应该返回什么？-需要什么返回什么？
    /// 加载 AccessToken
    ///
    /// - parameter code:       授权码
    /// - parameter completion: 完成回调[是否成功]
    func loadAccessToken(code: String, completion: (isSuccess: Bool)->()) {
        
        let urlString = "https://api.weibo.com/oauth2/access_token"
        
        let params = ["client_id": WBAppKey,
                      "client_secret": WBAppSecret,
                      "grant_type": "authorization_code",
                      "code": code,
                      "redirect_uri": WBRedirectURI]
        
        // 发起网络请求
        request(method: .POST, URLString: urlString, parameters: params) { (json, isSuccess) in
            //print(json)
            
            // 如果请求失败，对用户账户数据不会有任何影响
            // 直接用字典设置 userAccount 的属性
            self.userAccount.yy_modelSet(with: (json as? [String: AnyObject]) ?? [:])
            
            // 加载当前用户信息
            self.loadUserInfo(completion: { (dict) in
                // 使用用户信息字典设置用户账户信息(昵称和头像地址)
                self.userAccount.yy_modelSet(with: dict)
                
                // 保存模型
                self.userAccount.saveAccount()
                
                print(self.userAccount)
                
                // 用户信息加载完成再，完成回调
                completion(isSuccess: isSuccess)
            })
        }
    }
}
