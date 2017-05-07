//
//  PPMessageItemRightView.h
//  PPMessage
//
//  Created by PPMessage on 2/6/16.
//  Copyright © 2016 PPMessage. All rights reserved.
//

#import "PPMessageItemBaseView.h"
#import "PPSquareImageView.h"

extern CGFloat const PPMessageItemRightViewDefaultBubbleCornerRadius;

@interface PPMessageItemRightView : PPMessageItemBaseView

//@property (nonatomic) PPSquareImageView *avatarImageView;
//@property (nonatomic) UILabel *nameLabel;

@property (nonatomic) UIColor *bubbleColor;
@property (nonatomic) CGFloat bubbleCornerRadius;

@property (nonatomic) UIView *leftView;

@end
